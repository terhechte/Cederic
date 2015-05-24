//
//  Kjue.swift
//  Cederic
//
//  Created by Benedikt Terhechte on 22/05/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation

private let kKjueQueueListSize = 32
struct KjueQueue {
    let queue: Int32
    let name: String
    
    init(name: String, filters: [KjueFilter] = []) {
        self.queue = kqueue()
        self.name = name
        filters.map {self.addFilter($0)}
    }
    
    func addFilter(filter: KjueFilter) {
        // Create the necessary flags
        let (filter, identifier, fflags, data) = filter.expand()
        // Create an event
        var aFilterEvent: kevent = kevent(ident: UInt(identifier),
            filter: Int16(filter),
            flags: UInt16(EV_ADD), fflags: UInt32(fflags), data: Int(data), udata: nil)
        // Register the Event
        kevent(self.queue, &aFilterEvent, 1, nil, 0, nil)
    }
    
    func destroy() {
        close(self.queue)
    }
    
    func blockingEvents(timeout: NSTimeInterval?) -> [KjueEvent] {
        var eventReceiveList = UnsafeMutablePointer<kevent>.alloc(kKjueQueueListSize)
        var up:  UnsafePointer<timespec> = nil
        
        if let t = timeout {
            let tv_sec = Int(t)
            let tv_nsec = Int((t * 1000000000.0) - Double(Int(t) * 1000000000))
            var ts = timespec(tv_sec: tv_sec, tv_nsec: tv_nsec)
            withUnsafePointer(&ts, { unsafePointer in
                up = unsafePointer
            })
        }
        
        let newEventCount = kevent(self.queue, nil, Int32(0), eventReceiveList, Int32(kKjueQueueListSize), up)
        var results: [KjueEvent] = []
        for i in 0..<newEventCount {
            let aCEvent = eventReceiveList[Int(i)]
            let aEvent = KjueEvent(aKevent: aCEvent)
            results.append(aEvent)
            
            // Clear the Event from the queue
            var ev = kevent(ident: aCEvent.ident, filter: aCEvent.filter, flags: UInt16(EV_DISABLE), fflags: aCEvent.fflags, data: aCEvent.data, udata: aCEvent.udata)
            let postError = kevent(self.queue, &ev, 1, nil, 0, nil)
            /// FIXME: Error handling in case postError is -1
        }
        
        eventReceiveList.destroy()
        eventReceiveList.dealloc(kKjueQueueListSize)
        
        return results
        
    }
}

// http://nshipster.com/swift-collection-protocols/
extension KjueQueue : SequenceType {
    typealias Generator = GeneratorOf<KjueEvent>
    
    func generate() -> Generator {
        return GeneratorOf {
            while true {
                for ev in self.blockingEvents(nil) {
                    return ev
                }
            }
        }
    }
}

struct KjueEvent {
    var filter: KjueFilter
    var actions: [KjueActions]
    var udata: UnsafeMutablePointer<Void>
    
    init(filter: KjueFilter, actions: [KjueActions], udata: UnsafeMutablePointer<Void>) {
        self.filter = filter
        self.actions = actions
        self.udata = udata
    }
    
    /// Initialize a KjueEvent from a C kevent
    init(aKevent: kevent) {
        self.filter = KjueFilter.fromEven(aKevent.filter, identifier: aKevent.ident, fflags: aKevent.fflags, data: aKevent.data)
        var initial: [KjueActions] = []
        for f in KjueActions.values() {
            if Bool((aKevent.flags & UInt16(f.rawValue)) == 1) {
                initial.append(f)
            }
        }
        self.actions = initial
        self.udata = aKevent.udata
    }
    
    /// Convert this structure into a C kevent struct
    func asKevent() -> kevent {
        let (filter, identifier, fflags, data) = self.filter.expand()
        let actions = self.actions.reduce(0, combine: {$0 | $1.rawValue})
        return kevent(ident: UInt(identifier), filter: Int16(filter), flags: UInt16(actions), fflags: UInt32(fflags), data: Int(data), udata: self.udata)
    }
}

enum KjueResult {
    case success
    case error(code: Int16, message: String)
}

func post(queue: KjueQueue, event: KjueEvent) -> KjueResult {
    var kEvent = event.asKevent()
    let er = kevent(queue.queue, &kEvent, 1, nil, 0, nil)
    if (er < 0) {
        return KjueResult.error(code: 0, message: "")
    }
    return KjueResult.success
}

/**
KjueFilter defines a filter on kernel events. Multiple event types are supported. 
Filter means that if you register a filter for this, you will only receive events of this type.

- UserEvent: User generated events. You can post these events yourself.
- ReadFD: Takes a descriptor as the identifier, and returns whenever there is data available to read.  The behavior of the fil- ter	is slightly different depending	on the descriptor type.
- WriteFD: Takes a descriptor as the identifier, and returns whenever it is possible to write to the descriptor.
- VnodeFD: Takes a file descriptor as the identifier and the events to watch for, and returns when one or more of the requested events occurs	on the descriptor.

As Swift does not allow setting enum values from non-literals, we can't use the original C struct values. Instead this is a copy of the original values from <sys/event.h>. Something which leads to errors once the values in event.h ever change.
*/

// FIXME: add the other filter types and their flags
enum KjueFilter {
    
    /**
    Filter flags vary based on the selected filter type (UserEvent, ReadFD, etc):
    
    - VNodeFlags: For VNodeFD Filters
    - ReadFlags: For ReadFD Filters
    - UserEventFlags: For UserEvent Filters
    */
    enum KjueFilterFlags {
        /**
        - Delete:  The unlink()	system call was	called on the file	referenced by the descriptor.
        - Write:  A write occurred on the file	referenced by the descriptor.
        - Extend:  The file referenced by the descriptor was extended.
        - Attrib:  The file referenced by the descriptor had its attributes changed.
        - Link:  The link count on the file changed.
        - Rename:  The file referenced by the descriptor was renamed.
        - Revoke:  Access to the file was revoked via revoke(2) or	the underlying file system was unmounted.
        */
        enum VNodeFlags : UInt32 {
            case Delete = 0x00000001
            case Write = 0x00000002
            case Extended = 0x00000004
            case Attrib = 0x00000008
            case Link = 0x00000010
            case Rename = 0x00000020
            case Revoke = 0x00000040
            case None = 0x00000080
            
            /// As it is not possible to iterate over Swift enums, we have to list all cases again
            static func values() -> [VNodeFlags] {
                return [Delete, Write, Extended, Attrib, Link, Rename, Revoke, None]
            }
        }
        
        /**
        - Ffnop:      Ignore the input	fflags.
        - Ffand:      Bitwise AND fflags.
        - Ffor:      Bitwise OR fflags.
        - Ffcopy:      Copy fflags.
        - Trigger:     Cause the event to be triggered.
        */
        enum UserEventFlags : UInt32 {
            case Ffnop = 0x00000000
            case Ffand = 0x40000000
            case Ffor = 0x80000000
            case Ffcopy = 0xc0000000
            case Trigger = 0x01000000
            
            /// As it is not possible to iterate over Swift enums, we have to list all cases again
            static func values() -> [UserEventFlags] {
                return [Ffnop, Ffand, Ffor, Ffcopy, Trigger]
            }
        }
        
        /**
        - Ffctrlmask:  Control mask for	fflags.
        - Fflagsmask:  User defined flag mask for fflags.
        */
        enum UserEventMask : UInt32 {
            case Ffctrlmask = 0xc0000000
            case Fflagsmask = 0x00ffffff
            
            /// As it is not possible to iterate over Swift enums, we have to list all cases again
            static func values() -> [UserEventMask] {
                return [Ffctrlmask, Fflagsmask]
            }
        }
    }

    case UserEvent(identifier: UInt, fflags: [KjueFilterFlags.UserEventFlags], data: Int)
    case ReadFD(fd: UInt, data: Int)
    case WriteFD(fd: UInt, data: Int)
    case VnodeFD(fd: UInt, fflags: [KjueFilterFlags.VNodeFlags], data: Int)
    
    /* TODO: As a way to simplify the following code:
func blankof<T>(type:T.Type) -> T {
var ptr = UnsafeMutablePointer<T>.alloc(sizeof(T))
var val = ptr.memory
ptr.destroy()
return val
}
*/

    static func fromEven(filter: Int16, identifier: UInt, fflags: UInt32, data: Int) -> KjueFilter {
        if Bool((filter & Int16(EVFILT_USER)) == 1) {
            var initial: [KjueFilterFlags.UserEventFlags] = []
            for f in KjueFilterFlags.UserEventFlags.values() {
                if Bool((fflags & UInt32(f.rawValue)) == 1) {
                    initial.append(f)
                }
            }
            return UserEvent(identifier: identifier, fflags: [], data: data)
        } else if Bool((filter & Int16(EVFILT_VNODE)) == 1) {
            var initial: [KjueFilterFlags.VNodeFlags] = []
            for f in KjueFilterFlags.VNodeFlags.values() {
                if Bool((fflags & UInt32(f.rawValue)) == 1) {
                    initial.append(f)
                }
            }
            return VnodeFD(fd: identifier, fflags: initial, data: data)
        } else if Bool((filter & Int16(EVFILT_READ)) == 1) {
            return ReadFD(fd: identifier, data: data)
        } else { // Write
            return WriteFD(fd: identifier, data: data)
        }
    }
    
    /**
    Convert this Enum into the filter, the identifier, the fflags and the data. Returned as a tuple
    :returns Tuple (filter, identifier, fflags, data)
    */
    func expand() -> (Int16, UInt, UInt32, Int) {
        switch self {
            // Due to the limitations of Generic Enums in Swift, the map/reduce code needs to be duplicated.
            // I tried a generic expand<T:RawRepresentable>(input: [T]) -> UInt32..., but couldn't satisfy the type checker
        case .UserEvent(let ident, let fflags, let data):
            let ry = fflags.map {$0.rawValue}.reduce(0) { $0 | $1}
            return (Int16(EVFILT_USER), ident, ry, data)
        case .ReadFD(let ident, let data):
            return (Int16(EVFILT_READ), ident, 0, data)
        case .WriteFD(let ident, let data):
            return (Int16(EVFILT_WRITE), ident, 0, data)
        case .VnodeFD(let ident, let fflags, let data):
            let ry = fflags.map {$0.rawValue}.reduce(0) { $0 | $1}
            return (Int16(EVFILT_VNODE), ident, ry, data)
        }
    }
}

/**
Actions are defined per event. The handling of the events changes based on the selected actions.
Multiple actions can be set for an event.

- Add:   Adds the event to the kqueue.  Re-adding an	existing event will modify	the parameters of the original event, and not result in a	duplicate entry.  Adding an event automati- cally enables it, unless overridden	by the EV_DISABLE flag.
- Enable:   Permit kevent() to return the event	if it is triggered.
- Disable:   Disable the	event so kevent() will not return it.  The filter itself is not disabled.
- Dispatch:  Disable the	event source immediately after delivery	of an event.  See	EV_DISABLE above.
- Delete:   Removes the	event from the kqueue.	Events which are attached to	file descriptors are automatically deleted on
- Receipt:   This flag is useful	for making bulk	changes	to a kqueue without draining any pending events.  When passed as input, it forces EV_ERROR to always	be returned.  When a filter is successfully added the data field	will be	zero.
- Oneshot:   Causes the event to	return only the	first occurrence of the	filter being triggered.	 After the user	retrieves the event from the kqueue, it is deleted.
- Clear:   After the event is retrieved by the	user, its state	is reset.  This is useful for filters which report state transitions	instead	of the current state.  Note that some filters may	automatically set this flag internally.
- Eof:   Filters may	set this flag to indicate filter-specific EOF condition.
- Error: Something went wrong
*/
enum KjueActions : UInt16 {
    case Add = 0x001
    case Enable = 0x004
    case Disable = 0x008
    case Dispatch = 0x080
    case Delete = 0x002
    case Receipt = 0x040
    case Oneshot = 0x010
    case Clear = 0x020
    case Eof = 0x8000
    case Error = 0x4000
    
    /// As it is not possible to iterate over Swift enums, we have to list all cases again
    static func values() -> [KjueActions] {
        return [Add, Enable, Disable, Dispatch, Delete, Receipt, Oneshot, Clear, Eof, Error]
    }
}



