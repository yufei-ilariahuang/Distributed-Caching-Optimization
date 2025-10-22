┌─────────────────────────────────────────────────────────────────────────────────┐
│                    DISTRIBUTED SYSTEMS DESIGN PATTERNS                          │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌─────────────────────┐
│   ARCHITECTURE           │  │   RESILIENCE             │  │   CONSISTENCY       │
├──────────────────────────┤  ├──────────────────────────┤  ├─────────────────────┤
│                          │  │                          │  │                     │
│ Monolith                 │  │ Circuit Breaker          │  │ Strong (CP)         │
│  • Single DB             │  │  • Fail fast             │  │  • Raft/Paxos       │
│  • Tight coupling        │  │  • Stop cascading        │  │  • 2PC (blocks!)    │
│  • Hard to scale         │  │  • Auto-recovery         │  │  • Bank transfers   │
│                          │  │                          │  │  • Minority unavail │
│         ↓                │  │ Bulkhead                 │  │                     │
│                          │  │  • Isolate resources     │  │ Eventual (AP)       │
│ Microservices (DDD)      │  │  • Thread pools          │  │  • Dynamo/Cassandra │
│  • Bounded contexts      │  │  • Connection pools      │  │  • Async replication│
│  • Independent scaling   │  │  • Prevent cascade       │  │  • Like counts      │
│  • Separate DBs          │  │                          │  │  • Always available │
│  • Team autonomy         │  │ Saga Pattern             │  │                     │
│                          │  │  • Local transactions    │  │ CAP Theorem         │
│ API Gateway              │  │  • Compensate on fail    │  │  • Pick 2 of 3:     │
│  • Single entry point    │  │  • No global locks       │  │    C, A, P          │
│  • Auth/routing          │  │                          │  │  • FLP: Perfection  │
│  • Aggregation           │  │                          │  │    impossible!      │
│                          │  │                          │  │                     │
└──────────────────────────┘  └──────────────────────────┘  └─────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌─────────────────────┐
│   RESOURCE MANAGEMENT    │  │   OBSERVABILITY          │  │   SCALING           │
├──────────────────────────┤  ├──────────────────────────┤  ├─────────────────────┤
│                          │  │                          │  │                     │
│ Thread Pool              │  │ Logs                     │  │ Vertical            │
│  • Reuse threads         │  │  • What happened         │  │  • Bigger machine   │
│  • Limit concurrency     │  │  • Debug specific issue  │  │  • Limits           │
│  • Prevent exhaustion    │  │                          │  │                     │
│                          │  │ Metrics (Prometheus)     │  │ Horizontal          │
│ Connection Pool          │  │  • System health         │  │  • More machines    │
│  • DB, HTTP, gRPC        │  │  • Alerting              │  │  • Stateless!       │
│  • Expensive to create   │  │  • P50/P95/P99           │  │  • Load balancer    │
│  • Reuse connections     │  │                          │  │  • Auto-scaling     │
│  • Prevent DB overload   │  │ Traces                   │  │                     │
│                          │  │  • Request journey       │  │ Key: Stateless      │
│ Bulkhead ≠ Pool          │  │  • Find bottlenecks      │  │  • No local state   │
│  • Isolate failures      │  │  • Span timeline         │  │  • External storage │
│  • Multiple pools        │  │                          │  │  • Any instance OK  │
│  • Prevent cascade       │  │ P99 > Average!           │  │                     │
│                          │  │  • Tail latencies matter │  │                     │
│                          │  │  • 1% @ scale = millions │  │                     │
└──────────────────────────┘  └──────────────────────────┘  └─────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              KEY TRADE-OFFS                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Monolith        ←→  Microservices    │  Strong Consistency  ←→  Availability  │
│  (Simple)            (Scalable)       │  (Correct)               (Fast)        │
│                                       │                                         │
│  Synchronous     ←→  Asynchronous     │  Average Latency     ←→  P99 Latency  │
│  (Predictable)       (Resilient)      │  (Misleading)            (Reality)     │
│                                       │                                         │
│  Perfection (FLP impossible) → Pragmatic Resilience (Contain failures) ✅      │
└─────────────────────────────────────────────────────────────────────────────────┘