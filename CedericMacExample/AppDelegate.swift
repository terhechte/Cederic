//
//  AppDelegate.swift
//  CedericMacExample
//
//  Created by Benedikt Terhechte on 26/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Cocoa
import Cederic

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var ag = AgentVal<[Int]>([1, 2, 3], validator: nil)

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        ag.send({ v in
            var y = v
            y.append(4)
            return y})
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

