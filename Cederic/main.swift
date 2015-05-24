//
//  main.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation


// Small test of send and running lots of agents

var a1 = Agent(initialState: 5, validator: {n in return n < 100})
print(a1.value)
a1.send({n in return n + 10})
let maxagents = 50000
var agents: [Agent<Int>] = []
for i in 1...maxagents {
    agents.append(Agent(initialState: 5, validator: {n in return n < 100}))
}

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
    while (true) {
        usleep(1000)
        let pos = Int(arc4random_uniform(UInt32(maxagents)))
        agents[pos].send({n in return n + 1})
    }
})

    sleep(1)
print(a1.value)

var s = 0
while(true) {
    var c = 0
    for ag in agents {
        c += (ag.value - 5)
    }
    println("after \(s) seconds \(c) iterations")
    s += 1
    sleep(1)
}


// alternative test without agents for performance benchmarking

/*
class agx {
    var value = 0
    init(v: Int) {
        self.value = v
    }
}


let maxagents = 50000
var agents: [agx] = []
for i in 1...maxagents {
    agents.append(agx(v: 0))
}

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
    while (true) {
        usleep(1000)
        let pos = Int(arc4random_uniform(UInt32(maxagents)))
//        agents[pos] = agents[pos] + 1
        agents[pos].value = agents[pos].value + 1
    }
})

    sleep(1)

var s = 0
while(true) {
    var c = 0
    for ag in agents {
        c += ag.value
    }
    println("after \(s) seconds \(c) iterations")
    s += 1
    sleep(1)
}
*/