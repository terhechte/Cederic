//
//  main.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation

println("Hello, World!")


var a1 = Agent(initialState: 5, validator: {n in return n < 100})
print(a1.deref())
a1.send({n in return n + 10})
print(a1.deref())
var agents: [Agent<Int>] = []
for i in 1...50 {
    agents.append(Agent(initialState: 5, validator: {n in return n < 100}))
}

while(true) {
    sleep(1)
    print("sleep")
print(a1.deref())
}

