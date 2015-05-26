//
//  Cederic.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import Dispatch

/*
TODO:
- 12% CPU on Retina 13" (2012) with 500 idle agents. Also leaks memory
- 10% CPU on Retina 13" (2012) with 5000 idle agents. No leaks. Much better.
- 0% CPU on Retina 13" (2012) with 50000 idle agents. No leaks.
- 42% CPU on Retina 13" (2012) with 50000 agents and (around) 1000 data updates / send calls per second
- 45% CPU on Retina 13" (2012) with 50000 agents and (around) 1000 data updates / send calls per second using abstracted-away Kjue Library for KQueue
- 30% CPU as a Release Build (Same configuration as above)
- 27% CPU as a Release Build (Same configuration as above)

- [ ] make .value bindings compatible (willChangeValue..)
- [ ] add lots and lots of tests
- [ ] define operators for easy equailty
- [x] find a better way to process the blocks than usleep (select?)
- [x] this is an undocumented mess. make it useful
- [x] solo and blocking actions
- [ ] make the kMaountOfPooledQueues dependent upon the cores in a machine
- [ ] don't just randomly select a queue in the AgentQueueManager, but the queue with the least amount of operations, or at least the longest-non-added one. (could use atomic operations to store this)
Most of the clojure stuff:
- [ ] Remove a Watch
- [ ] The watch fn must be a fn of 4 args: a key, the reference, its old-state, its new-state.
- [ ] error handling (see https://github.com/clojure/clojure/blob/028af0e0b271aa558ea44780e5d951f4932c7842/src/clj/clojure/core.clj#L2002
- [ ] restarting
- [x] update the code to use barriers

*/

let kAmountOfPooledQueues = 4
let kKqueueUserIdentifier = UInt(0x6c0176cf) // a random number

/**
    Create a new kqueue Object
    :returns: The file descriptor of the kernel queue
*/
private func setupQueue() -> Int32 {
    let k = kqueue()
    return k
}

/**
    Post a new message to a kqueue. The payload can be a pointer to something.
    :param: q A kqueue file descriptor, as returned by *setupQueue()*
    :param: value A pointer to a payload you wish to post to the kqueue
    :returns: A number > 0 for successful posting, and -1 if there is an error
*/
private func postToQueue(queue: Int32, value: UnsafeMutablePointer<Void>) -> Int32 {
    let flags = EV_ENABLE
    let fflags = NOTE_TRIGGER
    var kev: kevent = kevent(ident: UInt(kKqueueUserIdentifier), filter: Int16(EVFILT_USER), flags: UInt16(flags), fflags: UInt32(fflags), data: Int(0), udata: value)
    let newEvent = kevent(queue, &kev, 1, nil, 0, nil)
    return newEvent
}

/**
    Blocking read a value from a kqueue
    :param: q A kqueue file descriptor, as returned by *setupQueue()*
    :returns: A pointer to something. The pointer will be == nil if postToQueue was called with a nil pointer

    *Warning*: Always test the pointer against nil before unpacking the value pointed to with .memory
*/
private func readFromQeue(queue: Int32) -> UnsafeMutablePointer<Void> {
    var evlist = UnsafeMutablePointer<kevent>.alloc(1)
    let flags = EV_ADD | EV_CLEAR | EV_ENABLE
    var kev: kevent = kevent(ident: UInt(kKqueueUserIdentifier), filter: Int16(EVFILT_USER), flags: UInt16(flags), fflags: UInt32(0), data: Int(0), udata: nil)
    
    let newEvent = kevent(queue, &kev, 1, evlist, 1, nil)
    
    let m = evlist[0].udata
    
    evlist.destroy()
    evlist.dealloc(1)
    
    return m
}


/**
    Managing infrastructure for the agents. Pools all agents together and calls their process functions
    whenever there the state should change. Also manages the dispatch queues.
*/
private class AgentQueueManager {
    
    // This queue manages the process operations of all agents. It syncs the adding, removal, and calling of them.
    lazy var agentProcessQueue = dispatch_queue_create("com.stylemac.agentProcessQueue", DISPATCH_QUEUE_CONCURRENT)
    
    // This queue manages the adding of new actions to agents. It syncs the adding, removal, and calling of them.
    lazy var agentBlockQueue = dispatch_queue_create("com.stylemac.agentBlockQueue", DISPATCH_QUEUE_SERIAL)
    
    // This queue manages the actual calculation of the process actions. This is where the user-defined action block
    // will be processed
    lazy var agentQueuePool: [dispatch_queue_t] = {
        var p: [dispatch_queue_t] = []
        for i in 0...kAmountOfPooledQueues {
            p.append(dispatch_queue_create("com.stylemac.AgentPoolQueue-\(i)", DISPATCH_QUEUE_SERIAL))
        }
        return p
    }()
    
    var operations: [String: ()->()] = [:]
    var kQueue: Int32
    
    typealias AgentQueueOPID = String
    
    init() {
        // Register a Kjue Queue that filters user events
        self.kQueue = kqueue()
        self.perform()
    }
    
    /** Randomly select one of the available pool queues and return it */
    var anyPoolQueue: dispatch_queue_t {
        let pos = Int(arc4random_uniform(UInt32(kAmountOfPooledQueues) + UInt32(1)))
        return agentQueuePool[pos]
    }
    
    
    /** Add a new agent process operation to the internal operations dict
    :param op A process operation that will be called whenever new actions for the agent come in
    :returns: The unique queue id of this agent in the manager. Used to identify the agent to the manager in subsequent operations
    */
    func add(op: ()->()) -> AgentQueueOPID {
        let uuid = NSUUID().UUIDString
        dispatch_barrier_async(self.agentProcessQueue , { () -> Void in
            self.operations[uuid] = op
        })
        return uuid
    }
    
    /** Runs on a background queue and continously waits for new kqueue events, then takes the AgentQueueOPID out of
    the kqueue event, and performs the process function of the agent identified by the OPID.
    Runs on the system background queue, the processing happens on the agentProcessQueue, and from there on the pool queue
    */
    func perform() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            while (true) {
                let data = readFromQeue(self.kQueue)
                if data != nil {
                    let dataString = UnsafeMutablePointer<String>(data)
                    let sx = dataString.memory
                    
                    // Operations are processed on a concurrent queue, so that
                    // the individual agents change their state as fast as possible.
                    // the actual operation is processed on one of the agent pool queues
                    // anyway, so this will not block the concurrent queue too long
                    dispatch_async(self.agentProcessQueue, { () -> Void in
                        if let op = self.operations[sx] {
                            op()
                        }
                    })
                }
            }
        })
    }
}

// FIXME: Make sure this will only be evaluated once!
// maybe dispatch-once it?
private let queueManager = AgentQueueManager()


/** Agent can be given operations with two types:
- Solo: The operation may take a long time to complete, run it on a seperate thread
- Pooled: It is a fast operation, run it on the internal thread pool
*/
enum AgentSendType {
    case Solo
    case Pooled
}

/** Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations. Agents are submitted functions which are stored in a mailbox and then executed in order. The agent itself has state, but no logic. The submitted functions modify the state. Using an Agent is more akin to operating on a data-structure than interacting with a service.

    Usage:
    1. Initialize the agent with some state:
      let ag: Agent<[Int32]> = Agent([0, 1, 2, 3], nil)
    2. Update the state by sending it an action
      ag.send({ s in return s.append(4)})
    3. The update will happen asynchronously at some point in the future
    4. Retrieve the state of the agent via value:
      let v: [Int32] = ag.value
    5. Add a watch to be notified of any state changes
      ag.addWatch({(o, n) in println("new state \(n), old state \(o)")

    Features:
    - Use watches to get agent change notifications
    - Use validators to validate all change operations
    - Use sendOff instead of send if the operation will take a long amount of time
*/

public class Agent<T> {
    
    typealias AgentAction = (T)->T
    typealias AgentValidator = (T)->Bool
    typealias AgentWatch = (T)->Void
    
    public var value: T {
        return state
    }
    
    private var state: T
    private let validator: AgentValidator?
    private var watches:[AgentWatch]
    private var actions: [(AgentSendType, AgentAction)]
    private var opidx: AgentQueueManager.AgentQueueOPID = ""
    
    /**
    Initialize an Agent.
    :param: initialState The internal state that the agent should store
    :param: validator A validation function which will be given the proposed new state and the old state. Returns bool success if the state transition is valid
    */
    init(initialState: T, validator: AgentValidator?) {
        self.state = initialState
        self.validator = validator
        self.watches = []
        self.actions = []
        self.opidx = queueManager.add(self.process)
    }
    
    /**
    Add an action to the internal mailbox to be applied to the current state.
    The action will be processed on one of the pooled dispatch queues. If the actions
    are long running, use sendOff instead, which creates a new thread for the operation
    */
    func send(fn: AgentAction) {
        self.sendToManager(fn, tp: AgentSendType.Pooled)
    }
    

    /**
    Add an action to the internal mailbox to be applied to the current state.
    Creates a new thread for the operation. If the operation is simple and short running
    consider using send instead, which processes on the existing internal dispatch queue pool
    */
    func sendOff(fn: AgentAction) {
        self.sendToManager(fn, tp: AgentSendType.Solo)
    }
    
    /**
    Add a watch to the agent. Watches will be notified of any state changes
    */
    func addWatch(watch: AgentWatch) {
        self.watches.append(watch)
    }
    
    private func sendToManager(fn: AgentAction, tp: AgentSendType) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.append((tp, fn))
            postToQueue(queueManager.kQueue, &self.opidx)
        })
    }
    
    private func calculate(f: AgentAction) {
        let newValue = f(self.state)
        if let v = self.validator {
            if !v(newValue) {
                return
            }
        }
        
        self.state = newValue
        
        for watch in self.watches {
            watch(newValue)
        }
    }
    
    private func process() {
        var fn: (AgentSendType, AgentAction)?
        
        // FIXME: Loop over actions here? To process everything we have?
        if self.actions.count > 0 {
            dispatch_sync(queueManager.agentBlockQueue, { () -> Void in
                fn = self.actions.removeAtIndex(0)
            })
        } else {
            return;
        }
        
        switch fn {
        case .Some(.Pooled, let f):
            dispatch_async(queueManager.anyPoolQueue, { () -> Void in
                self.calculate(f)
            })
        case .Some(.Solo, let f):
            // Create and destroy a queue just for this
            let uuid = NSUUID().UUIDString
            let ourQueue = dispatch_queue_create(uuid, nil)
            dispatch_async(ourQueue, { () -> Void in
                self.calculate(f)
            })
        default: ()
        }
    }
}

