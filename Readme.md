## Cederick
### Clojure-Style Agents for Swift

> *Warning* Heavy work in progress. Still more or less a **research playground**

#### What are Agents?
Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations. Agents are submitted functions which are stored in a mailbox and then executed in order. The agent itself has state, but no logic. The submitted functions modify the state. Using an Agent is more akin to operating on a data-structure than interacting with a service.

> **TLDR** Agents wrap data to allow you non-blocking, thread-safe, asynchrounous access & modification

#### How to use?
You don't. Yet.


#### Status
- Version 0.0.2
- Lots of todos in the source
- No unit tests yet
- Most API not implemented yet
- ~~Leaks memory~~
- ~~High CPU consumption (10% for 500 idle agents)~~

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
* http://www.objc.io/issue-2/low-level-concurrency-apis.html

#### KQueue
* http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/tools/tests/xnu_quick_test/kqueue_tests.c
* https://stuff.mit.edu/afs/sipb/project/freebsd/head/tools/regression/kqueue/user.c
* http://stackoverflow.com/questions/16072395/using-kqueue-for-evfilt-user
* http://wanproxy.org/svn/trunk/event/event_poll_kqueue.cc
* http://julipedia.meroh.net/2004/10/example-of-kqueue.html
* https://www.freebsd.org/cgi/man.cgi?query=kqueue
* http://dev.eltima.com/post/93497713759/interacting-with-c-pointers-in-swift-part-2
* http://www.sitepoint.com/using-legacy-c-apis-swift/
* http://stackoverflow.com/questions/24058906/printing-a-variable-memory-address-in-swift
* https://code.openhub.net/file?fid=NoLWjNE3u4rGljKdSnTH06aaCdY&cid=A2IwCo_X-fA&s=%22%23define%20EV_SET%22&fp=133476&mp,=1&ml=1&me=1&md=1&projSelected=true#L0
* http://stackoverflow.com/questions/24146488/swift-pass-uninitialized-c-structure-to-imported-c-function

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

