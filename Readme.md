
## Cederic
### Agents for Swift
#### Agents are Non-Blocking, thread-safe, asynchrounous data structures

![Cederic Logo](static/cederic-logo-github.png)

> Non-blocking, thread-safe, asynchrounous access & modification of any immutable or mutable object

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)


#### Swift 2.0 Status
- Currently not tested yet with Swift 2.0 b4. 
- The current master branch works for Swift 2.0.
- If you need Swift 1.2 support, use version [0.0.6](https://github.com/terhechte/Cederic/releases/tag/v0.0.6). 

#### Consider the following code
8 Threads are replacing NSColor instances in a shared NSMutableArray:

```
let index = arc4random_uniform(UInt32(self.colorAgent.value.count))
            
self.colorAgent.send({ (a: NSMutableArray) -> Void in
    a.replaceObjectAtIndex(Int(index), withObject: self.color)
    })
```

This will lead to the following result:
![Cederic NSMutableArray Example](static/cederic-nsmut.gif)

For more, have a look at the example app, or continue reading.

#### What are Agents?
Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations. Agents are submitted functions which are stored in a mailbox and then executed in order. The agent itself has state, but no logic. The submitted functions modify the state. Using an Agent is more akin to operating on a data-structure than interacting with a service.

#### How does it work?
Cederic employs a lot of GCD machinery and functionality in order to simplify the process of sharing state among multiple threads. Instead of having to wrap your head around semaphores, `dispatch_barriers`, `dispatch_groups` and more, you can simply use Cederic and everything works.

#### How to use?
1. Add Cederic.swift to your project
2. Create an Agent:
`
var ag = Agent<[Int]>([1, 2, 3], validator: nil)
`
3. Process an operation on the Agent
`
ag.send { v in return y + [4]}
`

4. At some point later in time, the state will be updated
`
println(ag.value)
// returns [1, 2, 3, 4]
`

#### Status
- Basic API implemented
- 27% CPU as a Release Build on Retina 13" (2012) with 50000 agents and (around) 1000 data updates per second
- High memory consumption for many agents (60 mb vs. 4.5 mb for a similar non-asynchronous simple loop over such a structure)
- 10MB memory growth (from 50mb to 60mb) after ~4500000 data updates over the course of 2 hours (50.000 agents) 

### How does it work
Cederic maintains a process queue which handles all the registered agents.
Once a new action is send to modify the state of the agent, this action will be queued up.
The Kernel KQueue mechanism is then used to notify the process queue that there are updated
actions for the relevant agent. The process queue will then cause the agent to process the
actions and modiy the state. Through clever GCD machinery, all this is thread safe even when
being used from multiple threads.

#### TODO
- [x] add keypath watches, so that the watch only fires if a keypath is changed.. aw how to implement that... Implemented 'tags' instead, much easier for now (still experimental)
- [ ] Write more detailed documentation, with examples for Value types, Reference types, and better explanation
- [x] if actions are generated too fast, operations queue up, and it can take quite long until all operations have been processed
- [ ] add 'monitor' functionality: add an agent<Dictionary<Agent:Int>> to an agent, and this dictionary will contain the amount of queued up operations for all agents that register this monitor.
- [ ] think about switching from kqueue to dispatch_semaphore or mach ports
- [ ] accumulates a lot of memory over time
- [x] add 'map' to agent, so that a monadic bind can work on it, and so one doesn't have to do value.map
- [ ] add jazzy documentation (https://github.com/Realm/jazzy)
- [ ] Find a sane way to handle errors for the kqueue mechanisms, i.e. how to act, notify the user, what to do?

##### Version 0.1.2
- Added map operations to cederic:
Map over a value-based agent
```
    x: Agent<Int> = Agent(5)
    p = x.map {$0 * 2}
    p will be 10
```

Map over CollectionType-based agents
```
    x: Agent<[Int]> = Agent([1, 2, 3])
    p = x.map {$0 * 2}
    p will be [2, 4, 6]
```

Filter over CollectionType-based agents
```
// continuing the above example
x.filter {$0 >= 2}
//will yield [2, 3]
```

This greatly simplifies reading operations on agents.

##### Version 0.1
- Swift 2.0 support
- Improved memory handling, fixed memory errors
- Changed the signature of the send method for reference and value types
- Added restriction where reference types have to be of type NSObject, as the main use case for them are typically UI Elements

##### Version 0.0.6
- Fixed several threading issues
- Added support for cancelling remaining actions and getting feedback via a completion block once the cancelling is done and the agent stopped processing
- Started tagging the commits with versions. Managed to completely forget about this in the past.

##### Version 0.0.5
- Added Mac App Example
- Rewrote parts of the API
- Added cancelling support for queued up agent blocks
- Fixed several threading issues

##### Version 0.0.4
- Removed the Kjue library in order to simplify the code
- Added documentation
- Added support for watches and validators

##### Version 0.0.3
- Moved Kqueue operations in seperate Kjue library (will be a separate library soon)
- Dictionary-Based approach of flagging dirty processes by sending the dict key via the kqueue event, consumes far less cpu
- Now 50.0000 Agents can do 1000 (simple) data updates at 30% CPU on an old 2012 Retina 13" Macbook.
  Similar data updates on a non-dispatched, simple loop consume around 2-3%
- However, introduced a new memory leak

##### Version 0.0.2
- Switched to Kqueue for blocking calls instead of polling / sleeping
- Code Cleanup

#### What's with the name?
[Cederic is the name of Agent 0011](http://en.wikipedia.org/wiki/00_Agent): Mentioned briefly in the novel Moonraker as vanishing while on assignment in Singapore.


#### Informational Links

##### Clojure Agents
* http://clojure.org/agents
* http://www.dalnefre.com/wp/2010/06/actors-in-clojure-why-not/
* http://lethain.com/a-couple-of-clojure-agent-examples/
* http://stackoverflow.com/questions/3259296/how-clojures-agents-compare-to-scalas-actors
* https://www.chrisstucchio.com/blog/2014/agents.html
* https://github.com/clojure/clojure/blob/028af0e0b271aa558ea44780e5d951f4932c7842/src/clj/clojure/core.clj#L2002
* https://clojuredocs.org/clojure.core/agent
* https://clojuredocs.org/clojure.core/send
* https://clojuredocs.org/clojure.core/shutdown-agents

#### KQueue
* http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/tools/tests/xnu_quick_test/kqueue_tests.c
* https://stuff.mit.edu/afs/sipb/project/freebsd/head/tools/regression/kqueue/user.c
* https://www.freebsd.org/cgi/man.cgi?query=kqueue
