//
//  NSMutableArrayExample.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 05/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import AppKit
import Cederic

/**
  Simple NSView subclass that takes an NSArray of NSColors as data and draws each item as a n x n block */
class NSBlocksView : NSView {
    var content: NSArray? = nil {
        didSet {
           self.setNeedsDisplayInRect(self.frame)
        }
    }
    
    /// We always display 10 items per row
    let xItems = 10
    
    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        
        if let content = self.content {
            
            let cw = NSWidth(self.frame)
            let ch = NSHeight(self.frame)
            
            let w = CGFloat(cw) / CGFloat(self.xItems)
            let h = CGFloat(ch) / fmax(CGFloat(content.count / self.xItems), 1)
            
            var x: CGFloat = 0
            var y: CGFloat = 0
            for object in content {
                if let color = object as? NSColor {
                    let fillRect =
                    CGRectMake(x, y, w, h)
                    color.set()
                    NSRectFill(fillRect)
                }
                x += w
                if x >= cw {
                    x = 0
                    y += h
                }
            }
        }
    }
}

class MutableCalcOperation: NSOperation {
    var colorAgent: AgentRef<NSMutableArray>
    var color: NSColor
    
    init(agent: AgentRef<NSMutableArray>) {
        self.colorAgent = agent
        
        // Select a random Color range 20 - 220
        let randR = CGFloat(arc4random_uniform(200) + 20) / 255.0
        let randB = CGFloat(arc4random_uniform(200) + 20) / 255.0
        let randG = CGFloat(arc4random_uniform(200) + 20) / 255.0
        
        self.color = NSColor(calibratedRed: randR, green: randB, blue: randG, alpha: 1.0)
    }
    
    override func main() {
        while (true) {
            
            if self.cancelled {
                return
            }
            
            let index = arc4random_uniform(UInt32(self.colorAgent.value.count))
            
            self.colorAgent.send({ (inout a: NSMutableArray) -> NSMutableArray in
                a.replaceObjectAtIndex(Int(index), withObject: self.color)
                return a
            })
            
            // Wait a short amount of time
            usleep(1000 * arc4random_uniform(15))
        }
    }
}

class NSMutableArrayExampleController : NSViewController {
    
    @IBOutlet weak var blocksView: NSBlocksView!
    
    var queue: NSOperationQueue!
    
    var listAgent: AgentRef<NSMutableArray>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize with white content
        let colors = [NSColor](count: 100, repeatedValue: NSColor.whiteColor())
        self.blocksView.content = colors as NSArray
        
        self.queue = NSOperationQueue()
        self.queue.maxConcurrentOperationCount = 8
        
        self.listAgent = AgentRef(NSMutableArray(array: colors))
        
        self.listAgent.addWatch("mainWatch",
            watch: { (key, agent, state) -> Void in
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                self.blocksView.content = state
                })
        })
    }
    
    // MARK: -
    // MARK: Engine Operation
    
    /// Create 8 CalcOperations
    func turnOnEngine() {
        for _ in 0..<8 {
            let anOperation = MutableCalcOperation(agent: self.listAgent)
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
                return NSMutableArray()
            })
        }
    }
    
    @IBAction func startStop(sender: NSButton) {
        if sender.state == NSOffState {
            self.turnOffEngine()
        } else {
            self.turnOnEngine()
        }
    }
    
}