# Distributed Caching System - Architecture & Design

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                   DISTRIBUTED IN-MEMORY CACHING SYSTEM                          │
│                     Go • gRPC • Consistent Hashing • etcd                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```
## Request Flow: Cache Hit vs Miss

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           REQUEST HANDLING FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

CLIENT REQUEST: GET key="user:123"
        ↓
┌───────────────────────────────────┐
│  1. HASH KEY                      │
│  hash("user:123") = 0x7F2A4C      │
└───────────────────────────────────┘
        ↓
┌───────────────────────────────────┐
│  2. LOOKUP OWNER NODE             │
│  Consistent hash ring             │
│  "user:123" → Node B              │
└───────────────────────────────────┘
        ↓
    ┌───┴───────────┐
    │               │
    ↓               ↓
[Node == Me?]  [Node != Me?]
    │               │
    │               ↓
    │        ┌─────────────────────┐
    │        │  P2P FETCH (Node B) │
    │        │  gRPC call          │
    │        │  /GetKey RPC        │
    │        └─────────────────────┘
    │               │
    ↓               ↓
┌───────────────────────────────────┐
│  3. LOCAL LRU CHECK               │
│  ConcurrentMap lookup             │
│  O(1) access                      │
└───────────────────────────────────┘
        ↓
    ┌───┴──────────────┐
    │                  │
    ↓                  ↓
[Found?]          [Not Found?]
    │                  │
    │ CACHE HIT ✓      │ CACHE MISS ✗
    │ Latency: ~1ms    │
    │                  ↓
    │           ┌──────────────────────┐
    │           │  SINGLEFLIGHT CHECK  │
    │           │  Already fetching?   │
    │           └──────────────────────┘
    │                  │
    │                  ↓
    │           ┌──────────────────────┐
    │           │  CALL BACKEND        │
    │           │  getter(key)         │
    │           │  e.g., DB query      │
    │           │  Latency: ~50ms      │
    │           └──────────────────────┘
    │                  │
    │                  ↓
    │           ┌──────────────────────┐
    │           │  POPULATE CACHE      │
    │           │  LRU.Set(key, val)   │
    │           │  Maybe evict         │
    │           └──────────────────────┘
    │                  │
    └────────┬─────────┘
             ↓
     ┌──────────────────────┐
     │  RETURN BYTEVIEW     │
     │  Immutable data      │
     │  Zero-copy safe      │
     └──────────────────────┘
             ↓
        CLIENT RESPONSE


LATENCY COMPARISON:
├─ Cache Hit:        ~1ms   (LRU memory access)
├─ P2P Miss:         ~5ms   (gRPC + remote LRU)
└─ Backend Miss:    ~50ms   (DB query + cache populate)
```

### Problem, Team, and Overview of Experiments

*   **Problem:** Modern large-scale applications, particularly those in finance and real-time data, face a critical challenge: delivering data to users with minimal latency while managing heavy load on backend systems. Direct database queries for every request are slow and unscalable. This project solves this by creating a high-performance, distributed in-memory caching system. A distributed cache acts as a fast data-access layer, drastically reducing latency, decreasing load on primary data stores, and improving overall system resilience and scalability. This is crucial for platforms that process and distribute real-time data, where speed and reliability are paramount.

*   **Team:** This project is developed by a single engineer passionate about distributed systems and performance optimization. Their expertise lies in Go programming, system design, and implementing foundational components for scalable infrastructure.

*   **Overview of Experiments:** The project will be evaluated through a series of experiments focused on performance, scalability, and correctness. Key metrics will include:
    *   **Cache Hit Rate:** Measuring the effectiveness of the cache under various load patterns.
    *   **Latency:** Measuring the average and tail latencies for cache hits and misses.
    *   **Throughput:** Determining the number of requests per second the system can handle.
    *   **Scalability:** Analyzing how performance metrics change as new nodes are added to the cluster, demonstrating the effectiveness of the consistent hashing algorithm.
    *   **Correctness:** Unit and integration tests will validate the logic of each component (LRU eviction, consistent hashing, data retrieval).

### Project Plan and Recent Progress

*   **Recent Progress:** The foundational components of the caching system have been implemented and unit-tested. This includes the core LRU cache, the consistent hashing module for key distribution, the single-flight mechanism to prevent cache stampedes, and the peer-to-peer communication logic. Most recently, service registration using etcd has been completed, allowing nodes to announce their presence in the distributed system.

*   **Timeline and Breakdown of Tasks:**
    *   **Phase 1 (Complete):**
        *   Implement core LRU cache (`lru/`).
        *   Implement consistent hashing (`consistenthash/`).
        *   Implement single-flight execution (`singleflight/`).
        *   Implement main cache logic and peer communication (`geecache/`).
        *   Add service registration with etcd (`registry/register.go`).
    *   **Phase 2 (In Progress):**
        *   **Implement Service Discovery:** Finalize the `registry/discover.go` module to allow the cache to dynamically discover and react to changes in cluster membership via etcd.
    *   **Phase 3 (Next Steps):**
        *   **Integration and Benchmarking:** Integrate all components and conduct the performance experiments outlined above.
        *   **API Finalization:** Expose a clean, public API for the cache group.
        *   **Deployment:** Package the system for deployment.

### Objectives

*   **Short-Term:** To deliver a fully functional, production-ready distributed caching system. This includes completing the dynamic service discovery feature, conducting thorough testing and benchmarking, and ensuring the system is stable and reliable. The goal is to have a system where new cache nodes can be added or removed seamlessly with zero downtime.

*   **Long-Term:** The vision extends to creating a more advanced and feature-rich caching solution. Future work includes:
    *   **Replication:** Adding data replication for enhanced fault tolerance, so the failure of a single node does not lead to data loss.
    *   **Advanced Eviction Policies:** Exploring and implementing more sophisticated eviction algorithms beyond LRU (e.g., LFU, ARC).
    *   **Security:** Implementing authentication and authorization for cache access.
    *   **Monitoring and Observability:** Integrating with monitoring tools (like Prometheus) to provide detailed insights into cache performance and health.

### Related work

This project is inspired by and builds upon the concepts of several well-established systems and academic papers.
*   **Google's Groupcache:** This project is heavily influenced by the design of `groupcache`, a caching and cache-filling library that is part of Google's production infrastructure. It borrows concepts like single-flight request collapsing and peer-to-peer data fetching.
*   **Memcached:** A classic, simple, and high-performance distributed memory object caching system. This project shares the goal of providing a fast, in-memory key-value store but adds more sophisticated features like consistent hashing within the client library.
*   **Redis:** A more feature-rich in-memory data store that can be used as a database, cache, and message broker. While Redis offers more data structures, this project focuses on excelling at one thing: providing a scalable, distributed cache for arbitrary data blobs.
*   **Consistent Hashing:** The distribution of keys across nodes is based on the principles laid out in the original paper by Karger et al., which is fundamental to building scalable distributed storage systems.

### Methodology
## Scalability Analysis

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        SCALABILITY CHARACTERISTICS                              │
└─────────────────────────────────────────────────────────────────────────────────┘

HORIZONTAL SCALABILITY:
┌─────────────────────┐
│ Add Node to Cluster │
└──────┬──────────────┘
       ↓
┌─────────────────────────────────────────────────────────────┐
│ 1. New node registers with etcd                             │
│    /cache/{newNodeID} = {addr, timestamp}                   │
│                                                              │
│ 2. All nodes watch etcd detect the change                   │
│    Trigger hash ring recalculation                          │
│                                                              │
│ 3. Consistent hashing minimizes remapping                   │
│    • Old keys: (n)/(n+1) stay on same node                 │
│    • Affected keys: 1/(n+1) ≈ k/n                          │
│    • Load rebalance: O(k/n) key movements                   │
│                                                              │
│ 4. Zero downtime: No cluster pause needed                   │
│    Gradual rebalance during requests                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘


VERTICAL SCALABILITY:
┌─────────────────────────────────────────────────────────────┐
│ Increase Node Resources                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ Memory: Larger LRU cache size                               │
│   • More hot keys in memory                                 │
│   • Fewer backend calls                                     │
│   • Hit rate: Linear improvement                            │
│                                                              │
│ CPU: Faster processing (if bottleneck)                      │
│   • Concurrent requests: Limited by GOMAXPROCS              │
│   • gRPC benefits from parallelism                          │
│   • Throughput: Linear with cores                           │
│                                                              │
│ Network: Higher bandwidth                                   │
│   • Throughput ceiling: BW * 1MB = max reqs/sec            │
│   • Most operations: O(1) network roundtrips                │
│                                                              │
└─────────────────────────────────────────────────────────────┘


THROUGHPUT ESTIMATES (Single Node):
┌──────────────────────────────────────────────────────────┐
│ Cache Hit Rate 95%:                                      │
│   • Hit latency: 1ms                                     │
│   • Throughput: ~1,000 req/sec per node                  │
│   • Formula: 1000ms / 1ms = 1,000 ops                    │
│                                                          │
│ Cache Hit Rate 50%:                                      │
│   • Avg latency: 0.5 * 1ms + 0.5 * 50ms = 25.5ms        │
│   • Throughput: ~40 req/sec per node (DB bottleneck)     │
│                                                          │
│ Full Cluster (10 nodes, 95% hit rate):                   │
│   • Total: 10,000 req/sec                                │
│   • Scales linearly with node count                      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Key Metrics & Monitoring

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            PERFORMANCE METRICS                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

Cache Effectiveness:
├─ Hit Rate:         % of requests served from cache
│  ├─ Target: 95%+  (reduce backend load)
│  ├─ Healthy: 80%+
│  └─ Poor: <50%    (reconsider cache strategy)
│
├─ Eviction Rate:    % of keys removed due to LRU
│  ├─ Target: <1%   (cache size is sufficient)
│  ├─ High: >5%     (increase capacity or TTL)
│  └─ Zero: Possible with small working set
│
└─ Latency:          Time to serve request
   ├─ Cache Hit:      ~1ms   (must be sub-millisecond!)
   ├─ Cache Miss:    ~5-50ms (depends on backend)
   ├─ P2P Fetch:      ~5ms   (gRPC roundtrip)
   └─ Tail (p99):     <100ms (SLA requirement)


Node Cluster Health:
├─ Active Nodes:     Count of healthy cache nodes
│  ├─ Expected: stable
│  └─ Monitoring: etcd watch + TTL renewal
│
├─ Key Distribution: Standard deviation of keys/node
│  ├─ Target: Low SD (balanced hash ring)
│  ├─ Healthy: Within 10% of mean
│  └─ Poor: Some nodes overloaded
│
└─ Rebalance Time:   Time for hash ring stabilization
   └─ Target: <500ms (fast convergence)


Backend Pressure:
├─ Backend Queries:  Queries to data source
│  ├─ Reduced: 1/hit_rate factor
│  ├─ Good: 95% cache hit = 20x reduction
│  └─ Metric: queries/sec to DB
│
└─ SingleFlight Effectiveness:
   ├─ Collapsed Requests: Requests waiting on one inflight
   ├─ Stampede Prevention: Measure request collapse ratio
   └─ Metric: Avg wait group size > 1
```

---

## Project Structure

```
Distributed-Caching-Optimization/
│
├── lru/                           # Core LRU Cache Implementation
│   ├── lru.go                     # LRU data structure (doubly-linked list)
│   └── lru_test.go                # Unit tests (eviction, ordering)
│
├── consistenthash/                # Consistent Hashing Ring
│   ├── consistenthash.go          # Hash ring (virtual nodes, O(log n))
│   └── consistenthash_test.go     # Tests (key distribution, rebalancing)
│
├── singleflight/                  # Request Deduplication
│   ├── singleflight.go            # WaitGroup-based collapse
│   └── singleflight_test.go       # Tests (stampede prevention)
│
├── geecache/                      # Main Cache Logic
│   ├── geecache.go                # Cache group & routing
│   ├── geecache_test.go           # Integration tests
│   ├── byteview.go                # Immutable data container
│   ├── cache.go                   # Concurrent map wrapper
│   ├── http.go                    # HTTP server endpoint
│   └── peers.go                   # Peer interface
│
├── geecachepb/                    # Protocol Buffers (gRPC)
│   ├── geecachepb.proto           # Service definition
│   ├── geecachepb.pb.go           # Generated message code
│   └── geecachepb_grpc.pb.go      # Generated gRPC stubs
│
├── registry/                      # Cluster Membership
│   ├── register.go                # Node registration in etcd
│   └── discover.go                # Service discovery & watch
│
├── main.go                        # Application entry point
├── go.mod, go.sum                 # Go module dependencies
├── run.sh                         # Multi-node test script
└── README.md                      # Project documentation
```

---
The proposed system is a distributed cache written in Go, designed for simplicity and performance. The architecture consists of several key components:

1.  **Node-Local Cache:** Each node in the cluster maintains an in-memory LRU (Least Recently Used) cache for fast access to hot data.
2.  **Consistent Hashing:** A consistent hash ring is used to map each data key to a specific node in the cluster. This ensures that only a small fraction of keys need to be remapped when a node is added or removed, minimizing cache churn.
3.  **Peer-to-Peer Communication:** If a node receives a request for a key that it does not own, it uses the consistent hash ring to identify the correct peer. It then acts as a client, fetching the data from that peer via an HTTP or gRPC endpoint.
4.  **Single-Flight Mechanism:** To prevent cache stampedes (where multiple concurrent requests for a missing key all hit the backend data source), a single-flight mechanism is employed. It ensures that for any given key, only one request to the backend is in flight at any time.
5.  **Service Discovery with etcd:** Nodes are not statically configured. Instead, they register themselves with an etcd cluster upon startup. A discovery module on each node watches etcd for changes in cluster membership (nodes joining or leaving) and dynamically updates its consistent hash ring accordingly. This allows for elastic scaling and high availability.


### Preliminary Results

The individual components have been validated through comprehensive unit tests (`lru_test.go`, `consistenthash_test.go`, etc.), which serve as the initial set of results demonstrating correctness. For example, tests confirm that the LRU cache correctly evicts the least recently used item and that the consistent hash ring distributes keys as expected.

The next phase of results collection will involve integration benchmarking. The planned experiments will measure:
*   **Latency reduction:** Comparing response times for a sample application with and without the cache.
*   **Database load reduction:** Measuring the number of queries hitting the primary database under load, with and without the cache.
*   **Dynamic scaling impact:** Measuring the key re-balancing and temporary performance degradation when a new node is added to a live cluster.

Analysis of these results will be critical to fine-tuning the system for the final report.

### Impact

The significance of this project is twofold. First, it serves as a practical, hands-on implementation of a sophisticated distributed system, demonstrating a deep understanding of the principles required to build scalable, real-world infrastructure. Second, the resulting system is a valuable, reusable component for any developer building large-scale services. In an era where application performance and user experience are paramount, an effective caching layer is not a luxury but a necessity. By providing an open-source, easy-to-use, and high-performance distributed cache, this project empowers developers to build faster and more reliable applications, directly impacting end-users and business stakeholders who depend on them. For companies like Bloomberg, which operate at the intersection of big data, low latency, and high availability, the principles and implementation details of this project are directly applicable and highly valuable.


## Layer 1: Cluster Orchestration

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      CLUSTER MEMBERSHIP MANAGEMENT                              │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│   SERVICE REGISTRATION   │  │   DISCOVERY & WATCH      │  │  ELASTIC SCALING     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│                          │  │                          │  │                      │
│ registry/register.go     │  │ registry/discover.go     │  │ Dynamic Membership   │
│                          │  │                          │  │                      │
│ • Node startup           │  │ • Watch etcd changes     │  │ • Add nodes: O(k/n)  │
│ • Store in etcd          │  │ • Update hash ring       │  │   remapping          │
│ • Heartbeat/TTL          │  │ • Trigger rebalance      │  │                      │
│ • Self-healing           │  │ • Zero downtime          │  │ • Remove nodes:      │
│                          │  │                          │  │   graceful shutdown  │
│ etcd Key:                │  │ Watch triggers:          │  │                      │
│ /cache/{nodeID}          │  │ • GET /cache/*           │  │ Minimal key churn:   │
│ {addr, timestamp}        │  │ • Revision version       │  │ • Only k/n keys      │
│                          │  │ • Real-time updates      │  │   remapped (k nodes) │
│                          │  │                          │  │                      │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────┘
```

---

## Layer 2: Core Caching Engine

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        DATA ROUTING & DISTRIBUTION                              │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│  CONSISTENT HASHING      │  │   GEECACHE CORE          │  │  PEER-TO-PEER        │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│                          │  │                          │  │                      │
│ consistenthash/          │  │ geecache/geecache.go     │  │ geecache/peers.go    │
│                          │  │                          │  │ geecachepb/ (proto)  │
│ • Hash ring (2^31)       │  │ • Cache groups           │  │                      │
│ • Virtual nodes          │  │ • Fill function          │  │ • gRPC communication │
│ • Key → Node mapping     │  │ • Key routing            │  │ • HTTP fallback      │
│ • Replica placement      │  │                          │  │ • Binary proto bufs  │
│                          │  │ Flow:                    │  │                      │
│ O(log n) lookup time     │  │ 1. hash(key) → node      │  │ Peer election:       │
│ Minimal remapping on     │  │ 2. Is it me?             │  │ • Local cache first  │
│ node changes             │  │   ↓ Yes → Check LRU      │  │ • Consistent hashing │
│                          │  │   ↓ No → P2P fetch       │  │ • Network locality   │
│ Ring rebalance:          │  │ 3. Cache miss?           │  │                      │
│ • O(k/n) key movement    │  │   → SingleFlight call    │  │ Backoff strategy:    │
│   (k=keys, n=nodes)      │  │ 4. Return ByteView       │  │ • Exponential retry  │
│                          │  │                          │  │ • Circuit breaker    │
│                          │  │                          │  │                      │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────┘
```

---

## Layer 3: Node-Local Operations

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      PER-NODE CACHING COMPONENTS                                │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│    LRU CACHE             │  │  SINGLE-FLIGHT CONTROL   │  │  DATA SERIALIZATION  │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│                          │  │                          │  │                      │
│ lru/lru.go               │  │ singleflight/            │  │ geecache/byteview.go │
│                          │  │                          │  │                      │
│ • Doubly-linked list     │  │ • Deduplicate requests   │  │ • Immutable bytes    │
│ • O(1) eviction          │  │ • Prevents stampede      │  │ • Copy-on-write      │
│ • LRU ordering           │  │ • Single inflight per key│  │ • Zero-copy reads    │
│ • Configurable capacity  │  │                          │  │                      │
│                          │  │ Cache stampede:          │  │ Example:             │
│ Eviction: Remove oldest  │  │ 1M requests for key X    │  │ • Image: 5MB         │
│ accessed (head)          │  │ → 1M backend calls       │  │ • Serve millions     │
│                          │  │ SingleFlight: Wait group │  │ • No copy overhead   │
│ Hot data in memory       │  │ → 1 backend call        │  │                      │
│ • Fashion-online access  │  │ • Others wait result     │  │ Protobuf wire format:│
│ • Recency tracking       │  │ • Share response         │  │ • Compact encoding   │
│                          │  │                          │  │ • Language agnostic  │
│                          │  │                          │  │                      │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────┘

┌──────────────────────────┐
│   HTTP API SERVER        │
├──────────────────────────┤
│                          │
│ geecache/http.go         │
│                          │
│ • GET /cache/:key        │
│ • Health checks          │
│ • Metrics exposure       │
│ • Request validation     │
│                          │
│ Endpoint:                │
│ http://node:port/cache   │
│                          │
│ Response: ByteView       │
│ (protobuf or raw)        │
│                          │
└──────────────────────────┘
```

---



## Design Patterns & Trade-offs

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          DESIGN PATTERNS APPLIED                                │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│  CONSISTENCY MODEL       │  │  FAILURE RESILIENCE      │  │  PERFORMANCE TACTICS │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│                          │  │                          │  │                      │
│ CAP Theorem: Choose AP   │  │ Bulkhead Pattern         │  │ Single-Flight        │
│ • Availability priority  │  │ • Isolate failures       │  │ • Prevent stampede   │
│ • Eventual consistency   │  │ • Thread pools           │  │ • Collapse requests  │
│                          │  │ • Connection pools       │  │                      │
│ Eventually Consistent:   │  │ • Circuit breaker        │  │ Consistent Hashing   │
│ • No global locks        │  │ • Graceful degradation   │  │ • Minimize movement  │
│ • Local commits only     │  │                          │  │ • O(k/n) remapping   │
│ • Async replication      │  │ Timeouts:                │  │                      │
│                          │  │ • P2P RPC: 500ms         │  │ LRU Eviction         │
│ No 2PC (avoids blocking) │  │ • Backend: 2s            │  │ • Hot data in memory │
│ • Deadlock free          │  │ • etcd watch: realtime   │  │ • Recency bias       │
│ • Scalable              │  │                          │  │                      │
│                          │  │ Retry Strategy:          │  │ Zero-Copy ByteView   │
│ Leader Election (etcd)   │  │ • Exponential backoff    │  │ • Immutable sharing  │
│ • Watch/notify pattern   │  │ • Jitter to avoid storm  │  │ • No serialization   │
│ • Weak consistency OK    │  │ • Max retries: 3         │  │   overhead           │
│                          │  │                          │  │                      │
│ Data Replication:        │  │ Health Checks:           │  │ Peer Selection       │
│ • TTL-based invalidation │  │ • etcd TTL renewal       │  │ • Hash-based routing │
│ • Lease pattern (etcd)   │  │ • Node availability      │  │ • Consistent across  │
│ • Grace period on remove │  │ • Auto-deregister        │  │   nodes              │
│                          │  │                          │  │                      │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────┘
```

---



## Getting Started

```bash
# Start etcd (cluster coordination)
docker run -d --name etcd -p 2379:2379 \
  quay.io/coreos/etcd:v3.5.0

# Run multiple cache nodes (auto-discovery via etcd)
go run main.go -port 8001 -etcd http://localhost:2379
go run main.go -port 8002 -etcd http://localhost:2379
go run main.go -port 8003 -etcd http://localhost:2379

# Run benchmarks
go test -bench=. ./...

# Load testing with Locust
locust -f locustfile.py --host=http://localhost:8001
```

---

## Next Steps

- [ ] Complete `registry/discover.go` (dynamic rebalancing)
- [ ] Conduct end-to-end integration tests
- [ ] Benchmark against Redis
- [ ] Add monitoring (Prometheus metrics)
- [ ] Implement data replication for fault tolerance
- [ ] Deploy to Kubernetes with auto-scaling
