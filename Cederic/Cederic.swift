//
//  Cederic.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import Dispatch

// FIXME: Having multiple pooled queues without agent barriers fails hard time
// because two serial queues can perform two agent actions at the same time, right?
// SOLUTION: Agents always need to be connected to one serial queue from the start
let kAmountOfPooledQueues = 1
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
private func readFromQueue(queue: Int32) -> UnsafeMutablePointer<Void> {
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
//    lazy var agentProcessQueue = dispatch_queue_create("com.stylemac.agentProcessQueue", DISPATCH_QUEUE_CONCURRENT)
    lazy var agentProcessQueue = dispatch_queue_create("com.stylemac.agentProcessQueue", DISPATCH_QUEUE_SERIAL)
    
    lazy var agentProcessConcurrentQueue = dispatch_queue_create("com.stylemac.agentProcessConcurrentQueue", DISPATCH_QUEUE_CONCURRENT)
    
    // This queue manages the adding of new actions to agents. It syncs the adding, removal, and calling of them.
    lazy var agentBlockQueue = dispatch_queue_create("com.stylemac.agentBlockQueue", DISPATCH_QUEUE_SERIAL)
    
    // This queue manages the actual calculation of the process actions. This is where the user-defined action block
    // will be processed
    lazy var agentQueuePool: [dispatch_queue_t] = {
        var p: [dispatch_queue_t] = []
        for i in 0..<kAmountOfPooledQueues {
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
        let pos = Int(arc4random_uniform(UInt32(kAmountOfPooledQueues)))
        return agentQueuePool[pos]
    }
    
    
    /** 
    Add a new agent process operation to the internal operations dict
    
    :param: op A process operation that will be called whenever new actions for the agent come in
    :returns: The unique queue id of this agent in the manager. Used to identify the agent to the manager in subsequent operations
    */
    func add(op: ()->()) -> AgentQueueOPID {
        let uuid = NSUUID().UUIDString
        dispatch_barrier_async(self.agentProcessQueue , { () -> Void in
            self.operations[uuid] = op
        })
        return uuid
    }
    
    /**
    Remove an agent process from the internal operations dict

    :param: opid The unique queue id of the agent in the manager
    */
    func remove(opid: String) {
        dispatch_barrier_async(self.agentProcessQueue , { () -> Void in
            self.operations.removeValueForKey(opid)
        })
    }
    
    /** 
    Runs on a background queue and continously waits for new kqueue events, then takes the AgentQueueOPID out of
    the kqueue event, and performs the process function of the agent identified by the OPID.
    Runs on the system background queue, the processing happens on the agentProcessQueue, and from there on the pool queue
    */
    func perform() {
        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
        dispatch_async(self.agentProcessConcurrentQueue, { () -> Void in
            while (true) {
                let data = readFromQueue(self.kQueue)
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


/** 
    Agent can be given operations with two types:

    - Solo: The operation may take a long time to complete, run it on a seperate thread
    - Pooled: It is a fast operation, run it on the internal thread pool
*/
enum AgentSendType {
    case Solo
    case Pooled
}

/** 
    Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations. Agents are submitted functions which are stored in a mailbox and then executed in order. The agent itself has state, but no logic. The submitted functions modify the state. Using an Agent is more akin to operating on a data-structure than interacting with a service.

    Types:

    There are two types of Agents provided. One for value types, one for reference types.

    - Value Types: This agent receives actions which modify the value in place and return an updated value.

          ag.send({ (s: [Int]) -> [Int] in var return s + [4]})
          ag.send({ (s: Int) -> Int in return s * 20})
    
    - Reference Types: This agent receives an inout reference to the state and can modify it

          ag.send({ (s: [Int]) -> Void in s.append(4); return})
          ag.send({ (s: Int) -> Void in s +=4; return})

    Value type Agents have the advantage of offering validators which allow you to valify any state transition.
    You want to use a reference type agent if your state is a custom class, for example:

          class example { var prop: Int = 0 }
          ag.send({ (s: example) -> Void in s.prop += 5; return})

    Usage:

    1. Initialize the agent with some state:
      let ag: AgentValue<[Int32]> = Agent([0, 1, 2, 3], nil)
    2. Update the state by sending it an action (The update will happen asynchronously at some point in the near future)
      ag.send({ s in return s + [4]})
    4. Retrieve the state of the agent via value:
      let v: [Int32] = ag.value
    5. Add a watch to be notified of any state changes
      ag.addWatch({(o, n) in println("new state \(n), old state \(o)")

    Features:

    - Use watches to get agent change notifications
    - Use sendOff instead of send if the operation will take a long amount of time
    - Use validators to valify a state transition (only for AgentValue)
*/

public class Agent<T, U> {
    
    typealias AgentAction = U//(inout T)->Void
    typealias AgentWatch = (String, Agent<T, U>, T)->Void
    typealias AgentValidator = (Agent<T, U>, T, T) -> Bool
    
    public var value: T {
        return state
    }
    
    private var state: T
    private var watches: [String: AgentWatch]
    private var actions: [(AgentSendType, AgentAction)]
    private var validator: AgentValidator?
    private var opidx: AgentQueueManager.AgentQueueOPID = ""
    private var fu: U? = nil
    
    /**
    Initialize an Agent.
    
    :param: initialState The internal state that the agent should store
    :param: validator A validation function which will be given the proposed new state and the old state. Returns bool success if the state transition is valid
    */
    public init(_ initialState: T, validator: AgentValidator?) {
        self.state = initialState
        self.watches = [:]
        self.actions = []
        self.opidx = queueManager.add(self.process)
        self.validator = validator
    }
    
    deinit {
        queueManager.remove(self.opidx)
    }
    
    /**
    Add an action to the internal mailbox to be applied to the current state.
    The action will be processed on one of the pooled dispatch queues. If the actions
    are long running, use sendOff instead, which creates a new thread for the operation
    
    Your code will be executed on one of the pooled dispatch queues.
    */
    public func send(fn: AgentAction) {
        self.sendToManager(fn, tp: AgentSendType.Pooled)
    }
    

    /**
    Add an action to the internal mailbox to be applied to the current state.
    Creates a new thread for the operation. If the operation is simple and short running
    consider using send instead, which processes on the existing internal dispatch queue pool
    
    Your code will be executed on a serial dispatch queue specifically created for executing your code.
    */
    public func sendOff(fn: AgentAction) {
        self.sendToManager(fn, tp: AgentSendType.Solo)
    }
    
    /**
    Cancel any pending actions which have not been processed yet.
    This will remove all queued up actions except for those which are currently processing
    */
    public func cancelAll() {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.removeAll(keepCapacity: true)
        })
    }
    
    /**
    Add a watch to the agent. Watches will be notified of any state changes
    
    :param: key The identifier of the watch
    :param: watch The agentwatch fn.
    
    The AgentWatch will be called with the following parameters:
    
    1. The watch identifier key
    2. The current agent
    3. The new state
    
    - For AgentRef agents, the watch will be called *after* the state transition
    - For AgentValue agents, the watch will be called *before* the state transition (so that agent.value will
        point to the old value for comparison's sake)
    
    The watch code will be executed on the dispatch queue on which the action is performed,
    either one from the agent dispatch queue pool - in case of send - or on a specially created one
    - in case of sendOff.
    
    */
    public func addWatch(key: String, watch: AgentWatch) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.watches[key] = watch
        })
    }
    
    /**
    Remove a watch from the agent.
    
    :param: key The identifier of the watch.
    */
    public func removeWatch(key: String) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.watches.removeValueForKey(key)
        })
    }
    
    private func sendToManager(fn: AgentAction, tp: AgentSendType) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.append((tp, fn))
            postToQueue(queueManager.kQueue, &self.opidx)
        })
    }
    
    private func calculate() {
        assertionFailure("Please construct a AgentRef or a AgentValue.")
    }
    
    private func process() {
        
        // create a copy
        var actionsCopy: [(AgentSendType, AgentAction)] = self.actions
        
        if self.actions.count > 0 {
            dispatch_sync(queueManager.agentBlockQueue, { () -> Void in
                self.actions.removeAll(keepCapacity: true)
            })
        } else {
            return;
        }
        
        func processOnQueue(q: dispatch_queue_t, f: U) {
            dispatch_async(q, { () -> Void in
                // FIXME: having f be a parameter of calulate leads to EXC_BAD_ACCESS because the
                // func gets deallocated along the way. This seems to be because f is of unknown type U.
                // I could not find a better way of solving this except for storing f temporarily as a
                // object property. This should be ok, since operations are performed in Serial,
                // never overwriting the required action.
                self.fu = f
                self.calculate()
                self.fu = nil
            })
        }
        
        for fn in actionsCopy {
            switch fn {
            case (.Pooled, let f):
                processOnQueue(queueManager.anyPoolQueue, f)
            case (.Solo, let f):
                // Create and destroy a queue just for this
                let uuid = NSUUID().UUIDString
                let ourQueue = dispatch_queue_create(uuid, nil)
                processOnQueue(ourQueue, f)
            default: ()
            }
        }
    }
}


/**
    Initialize An Agent for Reference types state

    This means that any the actions are handed a inout reference to the state and can modify it at will.
    This also effectively disables validators as the operation cannot
    be undone.
*/
public class AgentRef<T> : Agent<T, (inout T)->Void> {
    
    public init(_ initialState: T) {
        super.init(initialState, validator: nil)
    }
    
    private override func calculate() {
        // Calculate the state modifications
        if let f = self.fu {
            f(&self.state)
            
            // Notify the watches
            for (key, watch) in self.watches {
                watch(key, self, self.state)
            }
        }
    }
}

/**
    Initialize An Agent for Value types state

    This means that any the actions are handed the current state as a value type.
    They're expected to return an updated version of the state.
*/
public class AgentVal<T> : Agent<T, (T) ->T> {
    
    public init(initialState: T, validator: AgentValidator?) {
        super.init(initialState, validator: validator)
    }
    
    //private override func calculate(f: AgentAction) {
    private override func calculate() {
        if let f = self.fu {
            // Calculate the new state
            var s = self.state
            let sx = f(s)
            
            // If there is a validator, see if it validates
            if let v = self.validator {
                let r = v(self, sx, self.state)
                if !r {
                    return
                }
            }
            
            // Notify the watches
            for (key, watch) in self.watches {
                watch(key, self, sx)
            }
            
            // Apply the state
            self.state = sx
        }
    }
}

