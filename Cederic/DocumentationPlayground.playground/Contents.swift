//: Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

//var u = 

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
}

let p = KjueActions.Add
let u = KjueActions.Disable

let v = p.rawValue | u.rawValue

let x = p.rawValue | p.rawValue | u.rawValue
