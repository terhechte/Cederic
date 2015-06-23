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
    var cederic: Agent<[[String: Int]]>?
    var cedericValidator: Agent<Int>?
    
    override func setUp() {
        super.setUp()
        let state = [["a": 1], ["b": 2], ["c": 3]]
        self.cederic = Agent(state, validator: nil)
        
        // Create an Agent with a validator that ignores values <= 5
        self.cedericValidator = Agent(10, validator: {(agent, old, new) -> Bool in
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
            
            let newState = 10
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
            
            let newState = 50
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
        let state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
        self.testStateTransition(state, modifier: { (v: [[String: Int]]) -> [[String: Int]] in
            return v + [["d": 4]]
        })
    }
    
    func testRemoveState() {
        let state = [["a": 1], ["b": 2]]
        self.testStateTransition(state, modifier: { (v: [[String: Int]]) -> [[String: Int]] in
            return Array(v[0..<(v.count-1)])
        })
    }
    
    func testChangeState() {
        let state = [["a": 0], ["b": 2], ["c": 3]]
        self.testStateTransition(state, modifier: { (v: [[String: Int]]) -> [[String: Int]] in
            return Array([["a": 0]] + v[1..<v.count])
        })
    }
    
    func testAddWatch() {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            let state = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
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
            
            _ = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
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
    
    func testOperators() {
        let state: [[String: Int]] = [["a": 1], ["b": 2], ["c": 3], ["d": 4]]
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            c <- state
            
            self.valifyExpect(readyExpectation, bx: { () -> Bool in
                if c.value == state {
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
}

class CedericFuncTests: XCTestCase {
    var cederic: Agent<[Int]> = {
        let state: [Int] = [1, 2, 3, 4, 5]
        return Agent(state, validator: nil)
    }()
    
    var cederic2: Agent<Int> = {
        return Agent(10, validator: nil)
    }()
    
    override func setUp() {
        super.setUp()
    }
    
    func testMapArrayInt() {
        let result = self.cederic.map { (a: Int) -> Int in
            return a * 2
        }
        XCTAssertEqual(result, [2, 4, 6, 8, 10])
    }
    
    func testMapInt() {
        let result = self.cederic2.map { (a: Int) -> Int in
            return a * 2
        }
        XCTAssertEqual(result, 20)
    }
    
    func testFilterArrayInt() {
        let result = self.cederic.filter { (s: Int) -> Bool in
            return s >= 3
        }
        XCTAssertEqual(result, [3, 4, 5])
    }
}


class CedericRefTests: XCTestCase {
    
    //var cederic: AgentRef<NSArray<String>>?
    var cederic: AgentRef<NSMutableArray>?
    
    override func setUp() {
        super.setUp()
        let state = NSMutableArray(array: [["a": 1], ["b": 2], ["c": 3]])
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
    
    func testStateTransition(newState: NSArray, modifier: (NSMutableArray)->Void) {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            c.send(modifier)
            
            self.valifyExpect(readyExpectation, bx: { () -> Bool in
                if c.value.isEqualToArray(newState as [AnyObject]) {
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
        let state = NSArray(array: [["a": 1], ["b": 2], ["c": 3], ["d": 4]])
        self.testStateTransition(state, modifier: { (v:NSMutableArray) -> Void in
            v.addObject(["d": 4])
        })
    }
    
    func testRemoveState() {
        let state = NSArray(array: [["a": 1], ["b": 2]])
        self.testStateTransition(state, modifier: { (v:NSMutableArray) in
            v.removeLastObject()
        })
    }
    
    func testChangeState() {
        let state = NSArray(array:[["a": 0], ["b": 2], ["c": 3]])
        self.testStateTransition(state, modifier: { (v:NSMutableArray) in
            v.replaceObjectAtIndex(0, withObject: ["a": 0])
        })
    }
    
    func testAddWatch() {
        if let c = self.cederic {
            let readyExpectation = expectationWithDescription("ready")
            
            let state = NSArray(array:[["a": 1], ["b": 2], ["c": 3], ["d": 4]])
            c.addWatch("w1", watch: { (k, ag, v) -> Void in
                if v == state {
                    readyExpectation.fulfill()
                }
            })
            
            c.send({ (v: NSMutableArray) in
                v.addObject(["d": 4])
            })
            
            waitForExpectationsWithTimeout(5, handler: { (e) -> Void in
                XCTAssertNil(e, "Error")
            })
        }
    }
    
    func testRemoveWatch() {
        if let c = self.cederic {
            var watchTriggered = false
            
            c.addWatch("w1", watch: { (k, ag, v) -> Void in
                watchTriggered = true
            })
            c.removeWatch("w1")
            
            c.send({ (v: NSMutableArray) in
                v.addObject(["d": 4])
            })
            
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
                sleep(2)
                XCTAssertFalse(watchTriggered, "Watch wasn't removed")
            })
        }
    }
    
    
}

class CedericPerfTests: XCTestCase {
    
    
    func testPerformanceExample() {
        // Run 50.000 agents, performing 1000 write operations
        self.measureBlock() {
            
            let maxagents = 50000
            var agents: [Agent<Int>] = []
            for _ in 1...maxagents {
                agents.append(Agent(5, validator: nil))
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
                var s = 1000
                while (s > 0) {
                    usleep(200)
                    let pos = Int(arc4random_uniform(UInt32(maxagents)))
                    agents[pos].send({ (v: Int) -> Int in
                        return v + 1
                    })
                    s -= 1
                }
            })
        }
    }
}
