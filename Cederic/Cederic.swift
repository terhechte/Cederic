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

- [ ] make .value bindings compatible (willChangeValue..)
- [ ] add lots and lots of tests
- [ ] define operators for easy equailty
- [x] find a better way to process the blocks than usleep (select?)
- [ ] this is an undocumented mess. make it useful
- [x] solo and blocking actions
- [ ] move most methods out of the class so that they're more functional and can be curried etc (i.e. send(agent, clojure)
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
let kKqueueUserIdentifier = UInt(0x6c0176ef) // a random number



/*!
@abstract lazy vars can only exist in a struc or class or enum right now so we've to wrap it
*/
class AgentQueueManager {
    lazy var agentConcurrentQueue = dispatch_queue_create("com.stylemac.agentConcurrentQueue", DISPATCH_QUEUE_CONCURRENT)
    lazy var agentProcessQueue = dispatch_queue_create("com.stylemac.agentProcessQueue", DISPATCH_QUEUE_SERIAL)
    lazy var agentBlockQueue = dispatch_queue_create("com.stylemac.agentBlockQueue", DISPATCH_QUEUE_SERIAL)
    lazy var agentQueuePool: [dispatch_queue_t] = {
        var p: [dispatch_queue_t] = []
        for i in 0...kAmountOfPooledQueues {
            p.append(dispatch_queue_create("com.stylemac.AgentPoolQueue-\(i)", DISPATCH_QUEUE_SERIAL))
        }
        return p
    }()
    var operations: [String: ()->()] = [:]
    var kQueue: KjueQueue
    
    typealias AgentQueueOPID = String
    
    init() {
        // Register a Kjue Queue that filters user events
        self.kQueue = KjueQueue(name: "com.stylemac.userEventKqueue", filters: [KjueFilter.UserEvent(identifier: kKqueueUserIdentifier, fflags: [], data: 0)])
        self.perform()
    }
    
    var anyPoolQueue: dispatch_queue_t {
        let pos = Int(arc4random_uniform(UInt32(kAmountOfPooledQueues) + UInt32(1)))
        return agentQueuePool[pos]
    }
    
    func add(op: ()->()) -> AgentQueueOPID {
        let uuid = NSUUID().UUIDString
        dispatch_barrier_async(self.agentConcurrentQueue , { () -> Void in
            self.operations[uuid] = op
        })
        return uuid
    }
    
    func perform() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            while (true) {
                for anEvent in self.kQueue {
                    
                    let dataString = UnsafeMutablePointer<String>(anEvent.udata)
                    
                    let sx = dataString.memory
                    
                    dispatch_async(self.agentConcurrentQueue, { () -> Void in
                        // FIXME: UNSAFE!!
                        if let op = self.operations[sx] {
                            op()
                        }
//                        dataString.destroy()
//                        dataString.dealloc(1)
                    })
                }
            }
        })
    }
}

// FIXME: Make sure this will only be evaluated once!
// maybe dispatch-once it?
var queueManager = AgentQueueManager()


enum AgentSendType {
    case Solo
    case Pooled
}

private var once = dispatch_once_t()

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
    private var stop = false
    private var opidx: AgentQueueManager.AgentQueueOPID = ""
    private var opidx_c: UnsafeMutablePointer<String> = nil
    
    init(initialState: T, validator: AgentValidator?) {
        
        self.state = initialState
        self.validator = validator
        self.watches = []
        self.actions = []
        self.opidx = queueManager.add(self.process)
        self.opidx_c = UnsafeMutablePointer<String>.alloc(1)
        self.opidx_c.initialize(self.opidx)
    }
    
    func sendToManager(fn: AgentAction, tp: AgentSendType) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.append((tp, fn))
            let event = KjueEvent(filter: KjueFilter.UserEvent(identifier: kKqueueUserIdentifier,
                fflags: [KjueFilter.KjueFilterFlags.UserEventFlags.Trigger], data: 0),
                actions: [KjueActions.Enable], udata: self.opidx_c)
            post(queueManager.kQueue, event)
        })
    }
    
    func send(fn: AgentAction) {
        self.sendToManager(fn, tp: AgentSendType.Pooled)
    }
    
    func sendOff(fn: AgentAction) {
        self.sendToManager(fn, tp: AgentSendType.Solo)
    }
    func addWatch(watch: AgentWatch) {
        self.watches.append(watch)
    }
    func destroy() {
        self.stop = true
        self.opidx_c.destroy()
        self.opidx_c.dealloc(1)
    }
    func calculate(f: AgentAction) {
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
    
    func process() {
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

