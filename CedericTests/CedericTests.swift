//
//  CedericTests.swift
//  CedericTests
//
//  Created by Benedikt Terhechte on 27/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Cocoa
import Cederic
import XCTest

class CedericValTests: XCTestCase {
    var cederic: AgentVal<[[String: Int]]>?
    var cedericValidator: AgentVal<Int>?
    
    override func setUp() {
        super.setUp()
        var state = [["a": 1], ["b": 2], ["c": 3]]
        self.cederic = AgentVal(initialState: state, validator: nil)
        
        // Create an Agent with a validator that ignores values <= 5
        self.cedericValidator = AgentVal(initialState: 10, validator: {(agent, old, new) -> Bool in
            if new <= 5 {
                return false
            } else {
                return true
            }
        })
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func valifyExpect(ex: XCTestExpectation, bx: ()->Bool) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
            while (true) {
                if bx() == true {
                    ex.fulfill()
                    break
                }
                usleep(100)
            }
        })
    }
    
    func testStateTransition(newState: [[String: Int]], modifier: ([[String: Int]])->[[String: Int]]) {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            c.send(modifier)
            
            self.valifyExpect(readyExpectation, bx: { () -> Bool in
                if c.value == newState {
                    return true
                } else {
                    return false
                }
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    func testValidatorIgnore() {
        if let c = self.cedericValidator {
            
            var newState = 10
            let readyExpectation = expectationWithDescription("ready")
            
            c.send({(s:Int)->Int in return 1})
            
            self.valifyExpect(readyExpectation, bx: { () -> Bool in
                if c.value == newState {
                    return true
                } else {
                    return false
                }
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    func testValidatorValidate() {
        if let c = self.cedericValidator {
            
            var newState = 50
            let readyExpectation = expectationWithDescription("ready")
            
            c.send({(s:Int)->Int in return 50})
            
            self.valifyExpect(readyExpectation, bx: { () -> Bool in
                if c.value == newState {
                    return true
                } else {
                    return false
                }
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    
    func testAddState() {
        var state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
        self.testStateTransition(state, modifier: { (v) -> [[String: Int]] in
            return v + [["d": 4]]
        })
    }
    
    func testRemoveState() {
        var state = [["a": 1], ["b": 2]]
        self.testStateTransition(state, modifier: { (v) -> [[String: Int]] in
            return Array(v[0..<(v.count-1)])
        })
    }
    
    func testChangeState() {
        var state = [["a": 0], ["b": 2], ["c": 3]]
        self.testStateTransition(state, modifier: { (v) -> [[String: Int]] in
            return Array([["a": 0]] + v[1..<v.count])
        })
    }
    
    func testAddWatch() {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            var state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
            c.addWatch("w1", watch: { (k, ag, v) -> Void in
                if v == state {
                    readyExpectation.fulfill()
                }
            })
            
            c.send({ (v) -> [[String: Int]] in
                var s = v
                s.append(["d": 4])
                return s
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    func testRemoveWatch() {
        if let c = self.cederic {
            var watchTriggered = false
            
            var state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
            c.addWatch("w1", watch: { (k, ag, v) -> Void in
                watchTriggered = true
            })
            c.removeWatch("w1")
            
            c.send({ (v) -> [[String: Int]] in
                var s = v
                s.append(["d": 4])
                return s
            })
            
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
                sleep(2)
                XCTAssertFalse(watchTriggered, "Watch wasn't removed")
            })
        }
    }
}

class CedericRefTests: XCTestCase {
    
    var cederic: AgentRef<[[String: Int]]>?
    
    override func setUp() {
        super.setUp()
        var state = [["a": 1], ["b": 2], ["c": 3]]
        self.cederic = AgentRef(state)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func valifyExpect(ex: XCTestExpectation, bx: ()->Bool) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            while (true) {
                if bx() == true {
                    ex.fulfill()
                    break
                }
                usleep(100)
            }
        })
    }
    
    func testStateTransition(newState: [[String: Int]], modifier: (inout [[String: Int]])->Void) {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            c.send(modifier)
            
            self.valifyExpect(readyExpectation, bx: { () -> Bool in
                if c.value == newState {
                    return true
                } else {
                    return false
                }
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    func testAddState() {
        var state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
        self.testStateTransition(state, modifier: { (v) -> Void in
            v.append(["d": 4])
            return
        })
    }
    
    // This test currently fails every third or so test. It seems to be some sort
    // of threading issue, I'm still looking into it.
    func testRemoveState() {
        var state = [["a": 1], ["b": 2]]
        self.testStateTransition(state, modifier: { (v) -> Void in
            v.removeLast()
            return
        })
    }
    
    func testChangeState() {
        var state = [["a": 0], ["b": 2], ["c": 3]]
        self.testStateTransition(state, modifier: { (v) -> Void in
            v.replaceRange(0..<1, with: [["a": 0]])
            return
        })
    }
    
    func testAddWatch() {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            var state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
            c.addWatch("w1", watch: { (k, ag, v) -> Void in
                if v == state {
                    readyExpectation.fulfill()
                }
            })
            
            c.send({ (v) -> Void in
                v.append(["d": 4])
                return
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    func testRemoveWatch() {
        if let c = self.cederic {
            var watchTriggered = false
            
            var state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
            c.addWatch("w1", watch: { (k, ag, v) -> Void in
                watchTriggered = true
            })
            c.removeWatch("w1")
            
            c.send({ (v) -> Void in
                v.append(["d": 4])
                return
            })
            
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
                sleep(2)
                XCTAssertFalse(watchTriggered, "Watch wasn't removed")
            })
        }
    }
    
    /** The following two tests are not directly Cederic related, but instead measure the performance
        difference of functional Array modification versus non-functional array modification. This is
        a good guidance as using functional modification on arrays looks much better, however seems to 
        perform much worse. Consider:
        Replacement: Functional: 1.153 sec, Mutating: 0.527 sec
        Appending: Functional: 0.057 sec, Mutating: 0.004 sec
    */
    func testArrayFuncReplace() {
        // Measure Replacement
        self.measureBlock() {
            var cx = 0
            for i in 0..<100000 {
                let ix = [i, i + 1, i + 2, i + 3, i + 4, i + 5]
                // we want to measure this
                let ix2 = [5 + i * 2] + Array(ix[1..<ix.count])
                
                let s = ix2.reduce(0, combine: (+))
                cx += s
            }
        }
        
    }
    
    func testArrayFuncAppend() {
        // Measure Appending
        self.measureBlock { () -> Void in
            var arx: [Int] = []
            for i in 0..<10000 {
                arx = arx + [i]
            }
        }
    }
    
    func testArrayNFuncReplace() {
        // Measure Replacement
        self.measureBlock() {
            var cx = 0
            for i in 0..<100000 {
                var ix = [i, i + 1, i + 2, i + 3, i + 4, i + 5]
                // We want to measure this
                ix.replaceRange(0..<1, with: [5 + i * 2])
                let s = ix.reduce(0, combine: (+))
                cx += s
            }
        }
        
    }
    
    func testArrayNFuncAppend() {
        // Measure Appending
        self.measureBlock { () -> Void in
            var arx:[Int] = []
            for i in 0..<10000 {
                arx.append(i)
            }
        }
    }
    
    
    func testPerformanceExample() {
        // Run 50.000 agents, performing 1000 write operations
        self.measureBlock() {
            
            let maxagents = 50000
            var agents: [AgentVal<Int>] = []
            for i in 1...maxagents {
                agents.append(AgentVal(initialState: 5, validator: nil))
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
                var s = 1000
                while (s > 0) {
                    usleep(200)
                    let pos = Int(arc4random_uniform(UInt32(maxagents)))
                    agents[pos].send({ n in return n + 1})
                    s -= 1
                }
            })
        }
    }
    
}
