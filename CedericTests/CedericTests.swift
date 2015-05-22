//
//  CedericTests.swift
//  CedericTests
//
//  Created by Benedikt Terhechte on 22/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Cocoa
import XCTest
import Cederic

class CedericTests: XCTestCase {
    
    var cederic: Agent
    
    override func setUp() {
        super.setUp()
        var state = [["a": 1], ["b": 2], ["c": 3]]
        self.cederic = Agent(initialState: state, validator: nil)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
