## Cederic
### Clojure-Style Agents for Swift

> Work in progress. You should not use this in production yet.

#### What are Agents?
Agents provide shared access to mutable state. They allow non-blocking (asynchronous as opposed to synchronous atoms) and independent change of individual locations. Agents are submitted functions which are stored in a mailbox and then executed in order. The agent itself has state, but no logic. The submitted functions modify the state. Using an Agent is more akin to operating on a data-structure than interacting with a service.

> **TLDR** Agents wrap data to allow you non-blocking, thread-safe, asynchrounous access & modification

#### How to use?
1. Add Cederic.swift to your project
2. Create an Agent:
`
var ag = AgentVal<[Int]>([1, 2, 3], validator: nil)
`
3. Process an operation on the Agent
`
ag.send({ v in return y + [4]})
`
(This is a bit cumbersome due to the Swift Value semantics and the Array type)

4. The state will be updated
`
println(ag.value)
// returns [1, 2, 3, 4]
`

#### Status
- Basic API implemented
- Lacks Documentation
- Lacks fancy example project
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
- [ ] if actions are generated too fast, operations queue up, and it can take quite long until all operations have been processed
- [ ] cancelling agent actions currently doesn't remove all the queued up dispatch actions. try to find a way to do that.
- [ ] define operators for easy equailty, changing and comparison
- [ ] allow to define a thread for watch registration
- [ ] Implement NSKeyValueObserving (would require subclassing from NSObject)

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
