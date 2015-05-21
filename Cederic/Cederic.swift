//
//  Cederic.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import Dispatch


// Agent

/*

; Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations (unlike coordinated change of multiple locations through refs).

;

agents are submitted functions which are stored in a mailbox and then executed in order.

The agent itself has state, but no logic.

(def x (agent 0))
(defn increment [c n] (+ c n))
(send x increment 5)  ; @x -> 5
(send x increment 10) ; @x -> 15
Using a Clojure agent is more akin to operating on a data-structure than interacting with a service

TODO:
- [ ] this is an undocumented mess. make it useful
- [ ] solo and blocking actions
- [ ] move most methods out of the class so that they're more functional and can be curried etc (i.e. send(agent, clojure)
Most of the clojure stuff:
- [ ] Remove a Watch
- [ ] The watch fn must be a fn of 4 args: a key, the reference, its old-state, its new-state.
- [ ] error handling (see https://github.com/clojure/clojure/blob/028af0e0b271aa558ea44780e5d951f4932c7842/src/clj/clojure/core.clj#L2002
- [ ] restarting

*/

// all Agents are placed on this queue
//var kAgentProcessQueue: dispatch_queue_t
//var kAgentBlockQueue: dispatch_queue_t
//var kAgentQueuePool: [dispatch_queue_t]

let kAmountOfPooledQueues = 4

/*!
@abstract lazy vars can only exist in a struc or class or enum right now so we've to wrap it
*/
class AgentQueueManager {
    lazy var agentProcessQueue = dispatch_queue_create("agentProcessQueue", DISPATCH_QUEUE_SERIAL)
    lazy var agentBlockQueue = dispatch_queue_create("agentBlockQueue", DISPATCH_QUEUE_SERIAL)
    lazy var agentQueuePool: [dispatch_queue_t] = {
        var p: [dispatch_queue_t] = []
        for i in 0...kAmountOfPooledQueues {
            p.append(dispatch_queue_create("AgentPoolQueue-\(i)", DISPATCH_QUEUE_SERIAL))
        }
        return p
    }()
    /* // compiler doesn't like this. should file a radar
    lazy var agentQueuePool: [dispatch_queue_t] = { ()->[dispatch_queue_t] in
        return 0...4.map { (n: Int)->dispatch_queue_t in
            dispatch_queue_create("AgentPoolQueue-\(n)", DISPATCH_QUEUE_SERIAL)
        }
    }()*/
    var anyPoolQueue: dispatch_queue_t {
        let pos = Int(arc4random_uniform(UInt32(kAmountOfPooledQueues) + UInt32(1)))
        return agentQueuePool[pos]
    }
}

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
    
    init(initialState: T, validator: AgentValidator?) {
        
        self.state = initialState
        self.validator = validator
        self.watches = []
        self.actions = []
        self.process()
    }
    
    func send(fn: AgentAction) {
        // add the fn to a queue
        // as the funcQueue is serial, this will never lead to a race condition
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.append((AgentSendType.Pooled, fn))
        })
    }
    func sendOff(fn: AgentAction) {
        dispatch_async(queueManager.agentBlockQueue, { () -> Void in
            self.actions.append((AgentSendType.Solo, fn))
        })
    }
    func addWatch(watch: AgentWatch) {
        self.watches.append(watch)
    }
    func destroy() {
        self.stop = true
    }
    func deref() -> T {
        return state
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
        // this fn is being run on a concurrent queue
        // and will continously process the fn's from the
        // fn queue
        dispatch_async(queueManager.agentProcessQueue, { () -> Void in
            while (!self.stop) {
                
                var fn: (AgentSendType, AgentAction)?
                
                dispatch_sync(queueManager.agentBlockQueue, { () -> Void in
                    if self.actions.count > 0 {
                        fn = self.actions.removeAtIndex(0)
                    }
                })
                
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
                
                usleep(1000)
            }
        })
    }
}

