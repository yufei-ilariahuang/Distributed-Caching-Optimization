```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Traffic                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Application Load Balancer (ALB)                             │
│  - Port 443 (HTTPS with ACM certificate)                    │
│  - Target: API Frontend instances                           │
│  - Health Check: GET /health → 200 OK                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  API Frontend Layer (ECS Fargate - Stateless)               │
│  - Auto Scaling: 2-10 instances based on CPU/latency        │
│  - Port 9999: HTTP API for external clients                 │
│  - Port 2112: Prometheus metrics endpoint                   │
│  - Discovers cache nodes via AWS Cloud Map                  │
└────────────────────────┬────────────────────────────────────┘
                         │ gRPC
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Cache Node Cluster (ECS Fargate - Stateful)                │
│  - 3-12 nodes across 3 AZs for HA                           │
│  - Port 8001: gRPC peer-to-peer communication               │
│  - Port 7000: Raft consensus protocol                       │
│  - Port 2112: Prometheus metrics                            │
│  - Each node: LRU cache + Consistent hash ring + Raft       │
└────┬────────────────────────┬─────────────────────┬─────────┘
     │                        │                     │
     │ Cache Miss             │ Cluster Metadata    │ Metrics
     ▼                        ▼                     ▼
┌──────────────┐   ┌───────────────────┐   ┌──────────────────┐
│ RDS Postgres │   │ Raft Consensus    │   │ Prometheus +     │
│ (SlowDB)     │   │ - Membership      │   │ Grafana          │
│ - Multi-AZ   │   │ - Leader Election │   │ - 13 dashboards  │
│ - Read       │   │ - Hash Ring State │   │ - Real-time      │
│   Replicas   │   │ - EFS for logs    │   │   monitoring     │
└──────────────┘   └───────────────────┘   └──────────────────┘
```

# Core Components to Build
1. Enhanced Cache Layer (Upgrade Existing)
Current State:

✅ LRU cache with O(1) get/set
✅ Thread-safe operations with mutex
✅ Singleflight for cache stampede prevention
✅ Consistent hashing for key distribution

2. Raft Consensus Module (New - Core Addition)
What Raft Manages:

✅ Cluster membership (which nodes are alive)
✅ Leader election for coordination
✅ Consistent hash ring state (replicated across all nodes)
✅ Cache group configurations
❌ NOT cache data itself (too high volume)

3. gRPC Communication Layer (Replace HTTP)
Current: HTTP-based peer communication
New: gRPC with Protocol Buffers

4. AWS Cloud Map Service Discovery (New)
Purpose: Dynamic peer discovery in ECS environment

5. PostgreSQL Database Adapter (Replace In-Memory Map)
Current: var db = map[string]string{"Tom": "630", ...}
New: PostgreSQL with connection pooling

6. Observability Stack (Prometheus + Grafana)

# Grafana Dashboards (13 total):

Cache Overview: Hit rate, miss rate, throughput
Singleflight Efficiency: Coalescing ratio, wait times
Raft Cluster Health: Leader status, peer count, elections
Request Latency: P50/P95/P99 by operation
Database Load: Query rate, connection pool, slow queries
Consistent Hash Distribution: Key variance across nodes
ALB Metrics: Target health, request count, 5XX errors
ECS Auto-scaling: Task count, CPU/memory, scaling events
Memory Pressure: Cache size, eviction rate
gRPC Performance: Connection stats, error rate
Cost Dashboard: Data transfer, compute costs
Fault Injection Results: Disruption windows, recovery times
Experiment Comparison: Side-by-side metrics for all experiments

### **Scaling Dimensions**

#### **Horizontal Scaling (Primary)**

**1. Stateless API Frontend:**
- Scale: 2 → 50+ instances instantly
- Trigger: CPU > 70% or P95 latency > 200ms
- ALB distributes load round-robin
- Zero coordination between frontends

**2. Stateful Cache Nodes:**
- Scale: 3 → 12 nodes (always odd for Raft quorum)
- Add node process:
```
  1. ECS starts new task
  2. Task discovers peers via Cloud Map
  3. Joins Raft as learner (non-voter)
  4. Catches up on Raft log (10-30 seconds)
  5. Autopilot promotes to voter
  6. Raft proposes adding node to hash ring
  7. All nodes apply ring update
  8. Keys redistributed: K/N keys move to new node
```
Challenge: Cache miss spike during redistribution

3. Database Read Replicas:

Route cache misses across 1 primary + N replicas
Singleflight still prevents duplicate reads

### Vertical Scaling (Secondary)

Increase memory: 2GB → 8GB (more cache capacity)
Increase CPU: 1 vCPU → 4 vCPU (higher concurrency)
Use Fargate Spot for 70% cost savings on cache nodes

# Key Technical Challenges
1. Raft Bootstrap in Ephemeral ECS:

Problem: Tasks have dynamic IPs, Raft needs stable identity
Solution: Use EFS for persistent logs + Cloud Map for discovery + node ID from task metadata

2. Consistent Hash Ring Synchronization:

Problem: All nodes must agree on ring state for consistent key routing
Solution: Raft replicates hash ring configuration; all updates go through consensus

3. Graceful Node Addition:

Problem: Adding node causes cache invalidation for redistributed keys
Solution: Pre-warm new node's cache before adding to ring, monitor miss rate spike

4. ALB Health Check During Leader Election:

Problem: 5-second timeout during leader election causes request failures
Solution: Tune timeout to 2s, implement retry logic in frontend

5. Cost-Performance Trade-off:

Problem: More nodes = better hit rate but higher cost
Solution: Experiments determine optimal node count per workload


# 3 Scalability Experiments

### Experiment 1: Horizontal Scaling & Consistent Hashing Effectiveness
Hypothesis
The system scales from 3 to 12 cache nodes with:

- <15% variance in key distribution (consistent hashing working correctly)
- <20% cache hit rate drop during scaling events (minimized invalidation)
- ~Linear throughput improvement (doubling nodes ≈ doubles RPS capacity)
- <10-second cluster convergence after topology changes

### Experiment 2: Singleflight Protection Against Cache Stampede
Hypothesis
Singleflight prevents database overload during synchronized cache misses:

- 99%+ reduction in database queries (N concurrent requests → 1 query)
- <3x latency increase for coalesced requests vs. direct execution
- Zero connection pool exhaustion (stays below 100 connections)
- No memory leaks from unbounded singleflight groups

### Experiment 3: Multi-AZ Fault Tolerance & Raft Resilience
Hypothesis
System survives catastrophic failures with minimal disruption:

- Follower node failure: <0.1% error rate, zero user impact
- Leader node failure: 5-7 second disruption (ALB timeout + election), automatic recovery
- Entire AZ failure: <1% error rate, <10 second recovery, Raft maintains quorum
- Split-brain prevention: No dual-leader scenario, minority partition rejects writes
- Auto-healing: ECS replaces failed tasks within 90 seconds