//
//  Cederic.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import Dispatch

let kAmountOfPooledQueues = 4
let kKqueueUserIdentifier = UInt(0x6c0176cf) // a random number

/**
    Create a new kqueue Object
    - Returns: The file descriptor of the kernel queue
*/
private func setupQueue() -> Int32 {
    let k = kqueue()
    return k
}

/** 
    Post a new message to a kqueue. The payload can be a pointer to something.

    - parameter q: A kqueue file descriptor, as returned by *setupQueue()*
    - parameter value: A pointer to a payload you wish to post to the kqueue
    - returns: A number > 0 for successful posting, and -1 if there is an error
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

    - parameter q: A kqueue file descriptor, as returned by *setupQueue()*
    - returns: A pointer to something. The pointer will be == nil if postToQueue was called with a nil pointer

    *Warning*: Always test the pointer against nil before unpacking the value pointed to with .memory
*/
private func readFromQueue(queue: Int32) -> UnsafeMutablePointer<Void> {
    var evlist = UnsafeMutablePointer<kevent>.alloc(1)
    let flags = EV_ADD | EV_CLEAR | EV_ENABLE
    var kev: kevent = kevent(ident: UInt(kKqueueUserIdentifier), filter: Int16(EVFILT_USER), flags: UInt16(flags), fflags: UInt32(0), data: Int(0), udata: nil)
    
    kevent(queue, &kev, 1, evlist, 1, nil)
    
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
    lazy private var agentProcessQueue:dispatch_queue_t = { () -> dispatch_queue_t in
        return dispatch_queue_create("com.cederic.agentProcessQueue", DISPATCH_QUEUE_SERIAL)
        }()
    
    
    lazy var agentProcessConcurrentQueue:dispatch_queue_t = { ()->dispatch_queue_t in
        return dispatch_queue_create("com.cederic.agentProcessConcurrentQueue", DISPATCH_QUEUE_CONCURRENT)
        }()
    
    
    // This queue manages the adding of new actions to agents. It syncs the adding, removal, and calling of them.
    lazy var agentBlockQueue:dispatch_queue_t = { ()->dispatch_queue_t in
        return dispatch_queue_create("com.cederic.agentBlockQueue", DISPATCH_QUEUE_SERIAL)
        }()
    
    // This queue manages the actual calculation of the process actions. This is where the user-defined action block
    // will be processed
    lazy var agentQueuePool: [dispatch_queue_t] = {
        var p: [dispatch_queue_t] = []
        for i in 0..<kAmountOfPooledQueues {
            p.append(dispatch_queue_create("com.cederic.AgentPoolQueue-\(i)", DISPATCH_QUEUE_SERIAL))
        }
        return p
    }()
    
    var operations: [String: ()->()] = [:]
    var kQueue: Int32
    var lastPoolQueue = 0
    
    typealias AgentQueueOPID = String
    
    init() {
        // Register a Kjue Queue that filters user events
        self.kQueue = kqueue()
        self.perform()
    }
    
    /** Randomly select one of the available pool queues and return it */
    var anyPoolQueue: dispatch_queue_t {
        if lastPoolQueue >= kAmountOfPooledQueues {
            lastPoolQueue = 0
        }
        // FIXME: use a lock for this
        return agentQueuePool[lastPoolQueue++]
    }
    
    
    /** 
    Add a new agent process operation to the internal operations dict
    
    - parameter op: A process operation that will be called whenever new actions for the agent come in
    - returns: The unique queue id of this agent in the manager. Used to identify the agent to the manager in subsequent operations
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

    - parameter opid: The unique queue id of the agent in the manager
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
    
    - Reference Types: This agent receives a NSObject-based type (say an UI Element)

          ag.send({ (s: NSMutableArray) -> Void in s.addObject(4) })
          ag.send({ (s: UIButton) -> Void in s.enabled = true })

    Value type Agents have the advantage of offering validators which allow you to valify any state transition.
    You want to use a reference type agent if your state is a custom class, for example:

          class example { var prop: Int = 0 }
          ag.send({ (s: example) -> Void in s.prop += 5})

    Usage:

    1. Initialize the agent with some state:
      let ag: Agent<[Int32]> = Agent([0, 1, 2, 3], nil)
    2. Update the state by sending it an action (The update will happen asynchronously at some point in the near future)
      ag.send({ s in return s + [4]})
    4. Retrieve the state of the agent via value:
      let v: [Int32] = ag.value
    5. Add a watch to be notified of any state changes
      ag.addWatch({(agent, oldstate, newstate) in println("new state \(newstate), old state \(oldstate)")

    Features:

    - Use watches to get agent change notifications
    - Use sendOff instead of send if the operation will take a long amount of time
    - Use validators to valify a state transition (only for AgentValue)
*/

protocol AgentProtocol {
    typealias ElementType
    typealias AgentAction
    
    /// Type definition for a watch
    typealias AgentWatch
    
    /// Type definition for a validator
    typealias AgentValidator
}

extension AgentProtocol {
}

public class _AgentBase<T, A> : AgentProtocol {
    
    typealias ElementType = T
    
    typealias AgentAction = A
    
    /// Type definition for a watch
    typealias AgentWatch = (String, _AgentBase<T, A>, T)->Void
    
    /// Type definition for a validator
    typealias AgentValidator = (_AgentBase<T, A>, oldstate: T, newstate: T) -> Bool
    
    /// The agent's state
    private var state: ElementType
    
    /// Outstanding actions to be applied to the agent's state
    private var actions: [(AgentSendType, AgentAction)]
    
    /// Any watches that the user may have defined
    private var watches: [String: AgentWatch]
    
    /// The validator, if the user assigned one
    private var validator: AgentValidator?
    
    /// The agent manager identifier of this agent
    private var opidx: AgentQueueManager.AgentQueueOPID = ""
    
    /// The dispatch queue that this agent uses
    private var dispatchGroup: dispatch_group_t
    
    /// Upon creation, this is the queue we get assigned from the agent manager
    private var poolQueue: dispatch_queue_t
    
    /// When an agent cancels it's actions, this is set to true until all queue operations are cleared
    private var isCancelled = false
    
    /**
    Initialize an Agent.
    
    - parameter initialState: The internal state that the agent should store
    - parameter validator: A validation function which will be given the proposed new state and the old state. Returns bool success if the state transition is valid
    */
    public init(_ initialState: T, validator: AgentValidator?) {
        self.state = initialState
        self.validator = validator
        self.watches = [:]
        self.actions = []
        self.dispatchGroup = dispatch_group_create()
        self.poolQueue = queueManager.anyPoolQueue
        self.opidx = queueManager.add(self.process)
    }
    
    deinit {
        queueManager.remove(self.opidx)
    }
    
    private func calculate(state: T, fn: AgentAction) {
        fatalError("Cannot use the AgentBase")
    }
    
    
    // Internal accounting state to get a rough measure of outstanding tasks, mostly for
    // monitoring purposes
    private var processOnQueueCount = 0
    
    private func process() {
        
        // create a copy
        var actionsCopy: [(AgentSendType, AgentAction)]? = nil
        
        dispatch_sync(queueManager.agentBlockQueue, { () -> Void in
            actionsCopy = self.actions
            
            if self.actions.count > 0 {
                self.actions.removeAll(keepCapacity: true)
            } else {
                return;
            }
        })
        
        func processOnQueue(q: dispatch_queue_t, f: AgentAction) {
            self.processOnQueueCount += 1
            
            dispatch_group_enter(self.dispatchGroup)
            dispatch_group_async(self.dispatchGroup,
                q) { () -> Void in
                    
                    // Don't perform any further processing if the operations are cancelled
                    if !self.isCancelled {
                        self.calculate(self.state, fn: f)
                        self.processOnQueueCount -= 1
                    }
                    
                    dispatch_group_leave(self.dispatchGroup)
            }
        }
        
        if let act = actionsCopy  {
            for fn in act {
                switch fn {
                case (.Pooled, let f):
                    processOnQueue(self.poolQueue, f: f)
                case (.Solo, let f):
                    // Create and destroy a queue just for this
                    let uuid = NSUUID().UUIDString
                    let ourQueue = dispatch_queue_create(uuid, nil)
                    dispatch_group_wait(self.dispatchGroup, DISPATCH_TIME_FOREVER)
                    processOnQueue(ourQueue, f: f)
                }
            }
        }
    }
    
    /// Easy way for the user to access the agent's state
    public var value: T {
        return state
    }
    
    
    /**
    Add an action to the internal mailbox to be applied to the current state.
    The action will be processed on one of the pooled dispatch queues. If the actions
    are long running, use sendOff instead, which creates a new thread for the operation
    
    Your code will be executed on one of the pooled dispatch queues.
    */
    public func send(fn: A) {
        self.sendToManager(fn, tp: AgentSendType.Pooled)
    }
    

    /**
    Add an action to the internal mailbox to be applied to the current state.
    Creates a new thread for the operation. If the operation is simple and short running
    consider using send instead, which processes on the existing internal dispatch queue pool
    
    Your code will be executed on a serial dispatch queue specifically created for executing your code.
    */
    public func sendOff(fn: A) {
        self.sendToManager(fn, tp: AgentSendType.Solo)
    }
    
    /**
    Cancel any pending actions which have not been processed yet.
    This will remove all queued up actions except for those which are currently processing
    
    *Important:*
    
    Any new send/sendOff actions send after cancel and before the completion block triggers
    may or may not be executed. You should always wait for the completion to finish. Before sending new actions.
    
    - parameter completion: A completion block that will be executed once all outstanding actions have been cleared
    */
    public func cancelAll(completion: dispatch_block_t? = nil) {
        // If we're already cancelling, ignore this
        if self.isCancelled {
            return
        }
        
        self.isCancelled = true
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.removeAll(keepCapacity: true)
        })
        
        // Track when the dispatch group is empty
        // If the group is empty, the notification block object is submitted immediately.
        dispatch_group_notify(self.dispatchGroup,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
            { () -> Void in
                // This allows us to reset the cancel flag
                self.isCancelled = false
                if let c = completion {
                    c()
                }
        })
    }
    
    /**
    Add a watch to the agent. Watches will be notified of any state changes
    
    - parameter key: The identifier of the watch
    - parameter watch: The agentwatch fn.
    
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
    
    - parameter key: The identifier of the watch.
    */
    public func removeWatch(key: String) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.watches.removeValueForKey(key)
        })
    }
    
    private func sendToManager(fn: AgentAction, tp: AgentSendType) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.append((tp, fn))
            postToQueue(queueManager.kQueue, value: &self.opidx)
        })
    }
}


final public class Agent<T> : _AgentBase<T,(T)->T>  {
    
    typealias ElementType = T
    
    override public init(_ initialState: T, validator: AgentValidator?) {
        super.init(initialState, validator: validator)
    }
    
    override private func calculate(state: T, fn: AgentAction) {
        // Calculate the new state
        let sx = fn(state)
        
        // If there is a validator, see if it validates
        if let v = self.validator {
            let r = v(self, oldstate: self.state, newstate: sx)
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

/**
    Operator Overloading to quickly update with a new value
    
    This does only work for agents, not for AgentRefs
*/
infix operator <- { associativity left precedence 160 }

public func <- <T> (left: Agent<T>, right: T) -> Agent<T> {
    left.send { (v) -> T in
        return right
    }
    return left
}


/**
    Initialize An Agent for Reference types state

    This means that any the actions are handed a reference to the state and can modify it at will.
    This also effectively disables validators as the operation cannot be undone.
*/
final public class AgentRef<T where T:NSObject> : _AgentBase<T,(T)->Void>  {
    
    public init(_ initialState: T) {
        super.init(initialState, validator: nil)
    }

    override private func calculate(state: T, fn: AgentAction) {
            fn(self.state)
        
            // Notify the watches
            for (key, watch) in self.watches {
                watch(key, self, self.state)
            }
    }
}

