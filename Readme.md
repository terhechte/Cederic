## Cederick
### Clojure-Style Agents for Swift

> *Warning* Heavy work in progress. Still more or less a **research playground**

#### What are Agents?
Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations. Agents are submitted functions which are stored in a mailbox and then executed in order. The agent itself has state, but no logic. The submitted functions modify the state. Using an Agent is more akin to operating on a data-structure than interacting with a service.

> **TLDR** Agents wrap data to allow you non-blocking, thread-safe, asynchrounous access & modification

#### How to use?
You don't. Yet.


#### Status
- Version 0.0.1
- Lots of todos in the source
- No unit tests yet
- Most API not implemented yet
- Leaks memory
- High CPU consumption (10% for 500 agents)

#### What's with the name?
[Cederic is the name of Agent 0011](http://en.wikipedia.org/wiki/00_Agent): Mentioned briefly in the novel Moonraker as vanishing while on assignment in Singapore.


#### Informational Links

##### GCD
* https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/#//apple_ref/doc/uid/TP40008079-CH2-SW66
* https://www.mikeash.com/pyblog/friday-qa-2015-02-06-locks-thread-safety-and-swift.html
* http://www.objc.io/issue-2/thread-safe-class-design.html
* https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/#//apple_ref/c/macro/DISPATCH_QUEUE_CONCURRENT
* http://stackoverflow.com/questions/1550658/dispatch-queues-how-to-tell-if-theyre-running-and-how-to-stop-them
* http://blog.csdn.net/chuanyituoku/article/details/17473743

##### Swift
* http://www.codingexplorer.com/structures-swift/

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

