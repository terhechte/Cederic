//
//  main.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 21/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation

// Timing tests

struct SWKqueueQueue {
    let queue: Int32
    let name: String
    
    init(name: String) {
        self.queue = kqueue()
        self.name = name
    }
    func destroy() {
        close(self.queue)
        
    }
}

enum SWKqueueFilterFlags {
    enum VNodeFlags {
        case Delete
        case Write
        case Extended
        case Attrib
        case Link
        case Rename
        case Revoke
    }
}

enum SWKqueueFilter {
    case UserEvent(identifier: UInt, flags: UInt32)
    case ReadFD(fd: UInt, flags: UInt32)
    case WriteFD(fd: UInt, flags: UInt32)
    case VnodeFD(fd: UInt, flags: UInt32)
    // FIXME: add the others
}




let k = kqueue()
var ud: UnsafeMutablePointer<Int32> = nil

let c = EV_ADD
let f = 0
var kev: kevent = kevent(ident: UInt(42), filter: Int16(EVFILT_USER), flags: UInt16(c), fflags: UInt32(f), data: Int(0), udata: ud)
// Register
kevent(k, &kev, 1, nil, 0, nil)

// Events we want to monitor
//let chlist = UnsafeMutablePointer<kevent>.alloc(1)
//chlist[0] = kev

// Docs
// http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/tools/tests/xnu_quick_test/kqueue_tests.c
// https://stuff.mit.edu/afs/sipb/project/freebsd/head/tools/regression/kqueue/user.c
// http://stackoverflow.com/questions/16072395/using-kqueue-for-evfilt-user
// http://wanproxy.org/svn/trunk/event/event_poll_kqueue.cc
// http://julipedia.meroh.net/2004/10/example-of-kqueue.html
// https://www.freebsd.org/cgi/man.cgi?query=kqueue
// http://dev.eltima.com/post/93497713759/interacting-with-c-pointers-in-swift-part-2
// http://www.sitepoint.com/using-legacy-c-apis-swift/
// http://stackoverflow.com/questions/24058906/printing-a-variable-memory-address-in-swift
// https://code.openhub.net/file?fid=NoLWjNE3u4rGljKdSnTH06aaCdY&cid=A2IwCo_X-fA&s=%22%23define%20EV_SET%22&fp=133476&mp,=1&ml=1&me=1&md=1&projSelected=true#L0
// http://stackoverflow.com/questions/24146488/swift-pass-uninitialized-c-structure-to-imported-c-function

/* TODO
- [ ] Proper C Error handling, lots of unsafes around
- [ ] support more than just user events
- [ ] type safety by using proper swift enums?
*/

var cxx = 0
func swKqueuePostEvent() {
    let cx = EV_ENABLE
    let fx = NOTE_TRIGGER
    var udx: UnsafeMutablePointer<Int32> = UnsafeMutablePointer<Int32>.alloc(1)
    println("sending: \(cxx)")
    udx.memory = Int32(cxx)
    var ev = kevent(ident: UInt(42), filter: Int16(EVFILT_USER), flags: UInt16(cx), fflags: UInt32(fx), data: Int(0), udata: udx)
    let er = kevent(k, &ev, 1, nil, 0, nil)
    cxx += 1
}


//let t = dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC * 2))
//dispatch_after(t, dispatch_get_global_queue(0, 0)) { () -> Void in
//    while (true) {
//        swKqueuePostEvent()
//        swKqueuePostEvent()
//        swKqueuePostEvent()
//        swKqueuePostEvent()
//        //println("posting", er)
//        sleep(3)
//    }
//}

// Events that were triggered
var evlist = UnsafeMutablePointer<kevent>.alloc(10)

func address(o: UnsafePointer<Void>) -> Int {
    return unsafeBitCast(o, Int.self)
}

//while (true) {
//    println("Waiting for event")
//    var ev: UnsafeMutablePointer<kevent> = nil
//    
//    let newEvent = kevent(k, nil, 0, evlist, 10, nil)
//    
//    println("newevent", newEvent)
//    
//    if newEvent > 0 {
//        
//        let uvx = evlist[0].udata
//        println("got events (\(evlist[0].data))", address(&evlist))
//        let px = UnsafeMutablePointer<Int32>(uvx)
//        println(px.memory)
//        
//        let cx = EV_DISABLE
//        let fx = 0
//        var ev = kevent(ident: UInt(42), filter: Int16(EVFILT_USER), flags: UInt16(cx), fflags: UInt32(fx), data: Int(0), udata: ud)
//        let er = kevent(k, &ev, 1, nil, 0, nil)
//        println("cleaning", er)
//    }
//
//}

// Small test of send and running lots of agents
var a1 = Agent(initialState: 5, validator: {n in return n < 100})
print(a1.value)
a1.send({n in return n + 10})
print(a1.value)
var agents: [Agent<Int>] = []
for i in 1...5000 {
    agents.append(Agent(initialState: 5, validator: {n in return n < 100}))
}

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
    while (true) {
        usleep(10000)
        let pos = Int(arc4random_uniform(UInt32(5000)))
        agents[pos].send({n in return n + 1})
    }
})

var s = 0
while(true) {
    sleep(1)
    var c = 0
    for ag in agents {
        c += (ag.value - 5)
    }
    println("after \(s) seconds \(c) iterations")
    s += 1
}
