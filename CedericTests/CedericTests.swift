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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
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
            
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                sleep(2)
                XCTAssertFalse(watchTriggered, "Watch wasn't removed")
            })
        }
    }
    
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
