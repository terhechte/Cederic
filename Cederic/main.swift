//
//  main.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation

// test simplified queue code

/*
let k = setupQueue()

var s = "benedikt"

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
    while (true) {
    sleep(2)
//        withUnsafeMutablePointer(&s, {(ptr: UnsafeMutablePointer<Void>()) {
//            
//            })
//    println("post")
//        withUnsafeMutablePointer(&s, {ptr in
//            postToQueue(k, ptr)
//        })
        
        postToQueue(k, &s)
//        println("post", Int())
    }
})

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
    var evlist = UnsafeMutablePointer<kevent>.alloc(1)
    while (true) {
        
        let m = readFromQeue(k)
        
        let dataString = UnsafeMutablePointer<String>(m)
        if dataString != nil {
            println(dataString)
            let sx = dataString.memory
            println("r-", sx)
        }
    }
})
println("done")
while (true) {
    sleep(1)
}
*/

//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------

/*
// RAW KQUEUE CODE

let identifierNr = 0x6c0176ef // a random number

let k = kqueue()
var ud: UnsafeMutablePointer<Int32> = nil

let c = EV_ADD
let f = 0
var kev: kevent = kevent(ident: UInt(identifierNr), filter: Int16(EVFILT_USER), flags: UInt16(c), fflags: UInt32(f), data: Int(0), udata: ud)
// Register
kevent(k, &kev, 1, nil, 0, nil)


// Events that were triggered
var evlist = UnsafeMutablePointer<kevent>.alloc(10)

func address(o: UnsafePointer<Void>) -> Int {
    return unsafeBitCast(o, Int.self)
}

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
    sleep(2)
    close(k)
})

var udx:Int32 = 0
while (true) {
    println("Waiting for event")
    var ev: UnsafeMutablePointer<kevent> = nil
    
    let newEvent = kevent(k, nil, 0, evlist, 10, nil)
    
    //    println("newevent", newEvent)
    if (newEvent == -1) {
        println("error")
        break
    }
    
    if newEvent > 0 {
        
        if (Int32(evlist[0].flags) & EV_ERROR) == 1 {
            println("error 2")
            break
        }
        
        let uvx = evlist[0].udata
        println("got events (\(evlist[0].data))", address(&evlist))
    }
}

*/

//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------

// Raw test observing a file
/*

let k = kqueue()
var ud: UnsafeMutablePointer<Int32> = nil

let f = "/tmp/abc"
let fd = NSFileHandle(forReadingAtPath: f)

let c = EV_ADD | EV_ENABLE | EV_CLEAR
var ff = NOTE_DELETE | NOTE_EXTEND | NOTE_WRITE | NOTE_ATTRIB | NOTE_RENAME
ff = 0

var iiident = UInt(fd!.fileDescriptor)
iiident = 55

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
    while (true) {
        sleep(2)
        let cx = EV_ENABLE
        let fx = NOTE_TRIGGER
        var ev = kevent(ident: UInt(iiident), filter: Int16(EVFILT_USER), flags: UInt16(cx), fflags: UInt32(fx), data: Int(0), udata: nil)
        let er = kevent(k, &ev, 1, nil, 0, nil)
    }
})

//var kev: kevent = kevent(ident: iiident, filter: Int16(EVFILT_USER), flags: UInt16(c), fflags: UInt32(ff), data: Int(0), udata: nil)
// Register
//kevent(k, &kev, 1, nil, 0, nil)


// Events that were triggered
//var evlist = UnsafeMutablePointer<kevent>.alloc(10)

func address(o: UnsafePointer<Void>) -> Int {
    return unsafeBitCast(o, Int.self)
}

var udx:Int32 = 0
while (true) {
    println("Waiting for event")
    //var kkev: UnsafeMutablePointer<kevent> = nil
    
    var kev: kevent = kevent(ident: iiident, filter: Int16(EVFILT_USER), flags: UInt16(c), fflags: UInt32(ff), data: Int(0), udata: nil)
//    var kkev: kevent
    
    let newEvent = kevent(k, &kev, 1, &kev, 1, nil)
    
    //    println("newevent", newEvent)
    if (newEvent == -1) {
        println("error")
        break
    }
    
    if newEvent > 0 {
        
        println("new event", Int(kev.ident))
        
//        if (Int32(evlist[0].flags) & EV_ERROR) == 1 {
//            println("error 2")
//            break
//        }
//        
//        let uvx = evlist[0].udata
//        println("got events (\(evlist[0].data))", address(&evlist))
//        
//        let cx = EV_DISABLE
//        let fx = 0
//        var ev = kevent(ident: evlist[0].ident, filter: Int16(evlist[0].filter), flags: UInt16(cx), fflags: UInt32(fx), data: Int(0), udata: ud)
//        let er = kevent(k, &ev, 1, nil, 0, nil)
////        println("cleaning", er)
    }
}
*/


//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------

// Simple test of observing a file
/*
let f = "/tmp/abc"
let fd = NSFileHandle(forReadingAtPath: f)
if let ff = fd {
    println("descriptor", ff.fileDescriptor)
    let q = KjueQueue(name: "fileQueue", filter: KjueFilter.VnodeFD(fd: UInt(ff.fileDescriptor), fflags: [KjueFilter.KjueFilterFlags.VNodeFlags.Attrib,
        KjueFilter.KjueFilterFlags.VNodeFlags.Extended], data: 0))
    
    while (true) {
        println("go")
        let x = q.blockingEvents(nil)
        switch x {
        case .error(let code, let message):
            println("error", message)
        case .success(let r):
            for ev in r  {
                println("ev: ", ev.filter)
            }
        }
    }
}
println("end")
*/


//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------

// Small test of send and running lots of agents



//var a1 = Agent(initialState: 5, validator: {n in return n < 100})
//print(a1.value)
//a1.send({n in return n + 10})
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
//print(a1.value)

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



//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------


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