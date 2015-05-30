//
//  AppDelegate.swift
//  CedericMacExample
//
//  Created by Benedikt Terhechte on 26/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Cocoa
import Cederic

class CalcOperation: NSOperation {
    var listAgent: Agent<[String]>
    var controlAgent: AgentRef<NSSegmentedControl>
    var index: Int
    var counter: Int = 0
    
    init(listAgent: Agent<[String]>, controlAgent: AgentRef<NSSegmentedControl>, index: Int) {
        self.listAgent = listAgent
        self.controlAgent = controlAgent
        self.index = index
    }
    
    /** This main function just does a random calculation, waits a random amount of time,
        triggers the UI SegmentedControl, and inserts strings into the list */
    override func main() {
        while (true) {
            
            if self.cancelled {
                return
            }
            
            let randomValue = arc4random_uniform(100)
            
            // Tell the Segmented Control, that we're active
            self.controlAgent.send({(inout i:NSSegmentedControl) in
                
                // Important, in order to stay on the serial queue, we have to
                // run this code synchronous on the main thread
                dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                    i.selectedSegment = self.index
                    i.setLabel("OP \(self.index) (\(randomValue))", forSegment: self.index)
                    return
                })
                return i
            })
            
            // Wait a short amount of time
            usleep(1000 * arc4random_uniform(15))
            
            if self.cancelled {
                return
            }
            
            // Calculate a random string
            let string = "Operation \(self.index) - Value: \(counter)"
            counter += 1
            
            let cx = counter > 1000
            
            if cx {
                counter = 0
            }
            
            self.listAgent.send({(inout l: [String]) in
                // Insert at the top.
                if cx {
                    return [string]
                } else {
                    return [string] + l
                }
            })
            
            if self.cancelled {
                return
            }
            
            // Wait a longer amount of time
            usleep(10000 * arc4random_uniform(10))
            
            if self.cancelled {
                return
            }
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var segmentedControl: NSSegmentedControl!
    
    // Create the queue that holds our NSOperations
    var queue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.maxConcurrentOperationCount = 5
        return q
    }()
    
    // Create the agent that holds the list of strings
    var listAgent: Agent<[String]> = {
        let start: [String] = []
        return Agent(start, validator: nil)
    }()
    
    // The content of listAgent changes all the time. NSTableView has a delay
    // between asking for the number of rows and asking for cells. During this delay,
    // the content in the agent has changed. In order to remedy this, we copy the
    // contents of the agent whenever it changed, so that NSTableView always processes
    // on a stale copy.
    var listContentCopy: [String] = []
    
    // Create the agent that holds the NSSegmentedControl
    var controlAgent: AgentRef<NSSegmentedControl>?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Add a watch to the agent that will reload the table view once something changes
        self.listAgent.addWatch("mainWatch", watch: { (key, agent, state) -> Void in
            
            // assign any state changes to our table-view-controller
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                self.listContentCopy = state
                self.tableView.reloadData()
            })
        })
        
        // Add the agent that will handle control around our NSSegmentedControl
        self.controlAgent = AgentRef(self.segmentedControl)
    }
    
    /// Create 5 CalcOperations
    func turnOnEngine() {
        for i in 0..<5 {
            let anOperation = CalcOperation(listAgent: self.listAgent, controlAgent: self.controlAgent!, index: i)
            self.queue.addOperation(anOperation)
        }
    }
    
    /// Turn off calculations and clear anything remaining
    func turnOffEngine() {
        self.queue.cancelAllOperations()
        
        // We cancel any outstanding actions
        // And after that, clear the list
        self.listAgent.cancelAll { () -> Void in
            self.listAgent.send({(i) in
                // just "return []" fails as the type checker identifies [] as a NSArray *sigh*
                let s: [String] = []
                return s
            })
        }
        
        // Also cancel the control agent
        self.controlAgent.map {$0.cancelAll}
    }
    
    @IBAction func startStop(sender: NSButton) {
        if sender.state == NSOffState {
            self.turnOffEngine()
        } else {
            self.turnOnEngine()
        }
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return listContentCopy.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let s = listContentCopy[row]
        return s
    }


}

