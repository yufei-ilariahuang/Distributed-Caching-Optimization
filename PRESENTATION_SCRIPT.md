# Distributed Cache Deployment: LocalStack vs AWS Real Environment
## 15-Minute Oral Presentation Script

---

## **INTRODUCTION** (1 minute)

Good morning/afternoon everyone. Today I'm presenting my research comparing LocalStack and AWS real environment for deploying distributed caching systems.

**[SLIDE: Title + GitHub Link]**

This project addresses a critical challenge: how do we develop and test cloud-native applications efficiently without incurring massive AWS costs, while still ensuring production readiness?

My distributed caching system is inspired by Google's GroupCache, built in Go, and I've deployed it in both LocalStack and AWS to gather empirical evidence on their trade-offs.

---

## **PROBLEM STATEMENT** (1 minute)

**[SLIDE: The Developer's Dilemma]**

Every cloud developer faces this dilemma:

- **Option A: Develop directly on AWS**
  - ✅ Production-realistic
  - ❌ Slow iteration (154 seconds per deployment)
  - ❌ Expensive ($0.20/hour × 8 hours/day × 30 days = $48/month minimum)
  - ❌ Requires constant internet

- **Option B: Use LocalStack emulation**
  - ✅ Fast iteration (6 seconds)
  - ✅ Free
  - ❌ Is it realistic enough?

My research answers: **When should you use each environment?**

---

## **SYSTEM ARCHITECTURE** (2 minutes)

**[SLIDE: Architecture Diagram - AWS Real Environment]**

Let me walk you through what I built. This is a production-grade distributed caching system deployed on AWS:

```
AWS Cloud (VPC):
│
├── Application Load Balancer (public-facing, port 443)
│   │
│   └──> Routes to ──> ECS Cluster
│                       │
│                       ├── Task: API Frontend (port 9999)
│                       │   │
│                       │   └──> gRPC calls to cache nodes
│                       │
│                       ├── Task: GeeCache Node 1 (port 8001) ──┐
│                       ├── Task: GeeCache Node 2 (port 8002) ──┼─→ Auto-register with
│                       └── Task: GeeCache Node 3 (port 8003) ──┘   Cloud Map
│                                                                    (geecache.local)
│
├── AWS Cloud Map (Service Discovery)
│   └── DNS namespace: geecache.local
│       ├── node1.geecache.local → 10.0.1.100
│       ├── node2.geecache.local → 10.0.1.164
│       └── node3.geecache.local → 10.0.2.90
│
├── RDS PostgreSQL (Multi-AZ)
│   ├── Primary (us-east-1a): 100M product rows
│   └── Standby (us-east-1b): Auto-failover
│
└── CloudWatch
    ├── 51 Log Streams (task logs)
    └── 63 Metrics (Container Insights)
```

### **Key Components:**

### **1. Load Balancer Layer**
The Application Load Balancer distributes incoming HTTP requests across multiple API frontend instances. This ensures no single point of failure.

### **2. API Frontend (Auto-scaled)**
I'm running 2 to 50 Fargate tasks on port 9999. These are stateless services that accept client requests like:
```
GET /api?key=Tom → returns "630"
```

### **3. GeeCache Cluster (The Heart)**
This is where the magic happens. I have 3 to 12 stateful cache nodes with four key features:

**a) Raft Consensus (Port 7000)**
- Leader election ensures one node coordinates the cluster
- All nodes agree on the hash ring state
- Can tolerate losing one node without data loss

**b) Consistent Hashing**
- Maps `product_id → node` deterministically
- Uses 150 virtual nodes per real node for even distribution
- When I add or remove nodes, only 10% of keys get remapped

**c) LRU Cache (In-Memory)**
- Each node holds 4GB of hot data
- Total capacity: 4GB × 6 nodes = 24GB
- Achieves 92% cache hit rate on hot products

**d) Singleflight (Cache Breakdown Prevention)**
This is critical. Imagine 1000 users simultaneously request "Nike Shoes" when it's not cached. Without singleflight:
- ❌ 1000 database queries simultaneously
- ❌ Database crashes

With singleflight:
- ✅ Only 1 database query
- ✅ Other 999 requests wait and share the result
- ✅ 99% reduction in database load

### **4. RDS PostgreSQL (Multi-AZ)**
- Primary database in `us-east-1a` with 100 million product rows
- Standby replica in `us-east-1b` for auto-failover
- Handles only 8% of requests (cache misses)

**[SLIDE: Request Flow Example]**
1. Client requests `GET /api?key=Tom`
2. Load balancer routes to Frontend instance
3. Frontend calls `gee.Get("Tom")` via gRPC
4. Consistent hash determines: "Node 8001 owns this key"
5. Cache hit? Return immediately. Cache miss? Singleflight fetches from DB once.
6. Result: 630 (Tom's score)

---

## **BENCHMARK METHODOLOGY** (1.5 minutes)

**[SLIDE: Test Framework]**

I conducted 8 rigorous tests in both environments:

### **Test Categories:**

**1. Deployment Speed**
- Measure time from `terraform apply` to service healthy

**2. Scalability**
- Current task count
- Scale-up time (3 → 5 nodes)

**3. Service Discovery**
- How fast can nodes find each other?
- Cloud Map lookup latency

**4. Observability**
- Log streams available
- Metrics available (CloudWatch Container Insights)

**5. Network Performance**
- Inter-node latency
- Real vs simulated containers

All tests were automated using bash scripts in my GitHub repository. Each test ran 5 times, and I report the median values.

---

## **RESULTS: THE NUMBERS** (3 minutes)

**[SLIDE: Performance Comparison Table]**

Let me show you the data. This table tells the complete story.

### **🏆 LocalStack Wins: Development Speed**

**Test 1: Deployment Time**
- LocalStack: **6 seconds**
- AWS Real: **154 seconds**
- **Winner: LocalStack (25.7× faster)**

Why this matters: During development, you deploy dozens of times per day. LocalStack lets me test a change in 6 seconds vs waiting 2.5 minutes on AWS.

**Test 4: Horizontal Scaling**
- LocalStack: **4 seconds** to scale 3→5 nodes
- AWS Real: **32 seconds**
- **Winner: LocalStack (8× faster)**

This is critical when testing auto-scaling logic.

**Test 6: Cost**
- LocalStack: **$0/hour** (runs on laptop)
- AWS Real: **$0.20/hour** = $144/month for 24/7 operation
- **Winner: LocalStack (infinite ROI)**

For a student project with limited AWS Learner Lab credits, this is decisive.

---

### **🏆 AWS Real Wins: Production Realism**

**Test 5: Service Discovery**
- LocalStack: **Instances not registered** (Cloud Map simulation incomplete)
- AWS Real: **Full task network information** with private IPs
- **Winner: AWS Real**

This exposed a critical gap: LocalStack's Cloud Map doesn't fully replicate AWS behavior.

**Test 7: Network Latency**
- LocalStack: **10-50ms** (simulated API responses, not real containers)
- AWS Real: **1-5ms** (same VPC, actual container-to-container communication)
- **Winner: AWS Real (10× more realistic)**

For load testing, you need real network performance.

**Test 8: Observability**
- LocalStack: **0 log streams, 0 metrics**
- AWS Real: **51 log streams, 63 CloudWatch metrics**
- **Winner: AWS Real (essential for debugging)**

Example metrics AWS provides:
- `CpuUtilized`, `MemoryUtilized`
- `NetworkRxBytes`, `NetworkTxBytes`
- `RunningTaskCount`, `PendingTaskCount`

Without these, I'm flying blind in production.

---

**Test 2: Service Discovery Overhead**
This revealed interesting variability:
- LocalStack Cloud Map lookups: **754ms → 2304ms** (increasing latency, simulated)
- AWS Real ECS API: **100-300ms** (consistent, real network)

LocalStack's simulation degrades under load, which doesn't match reality.

---

## **EVIDENCE-BASED RECOMMENDATIONS** (3 minutes)

**[SLIDE: Use LocalStack When...]**

### **✅ Scenario 1: Rapid Development Iteration**

**Evidence:**
- Deployment: 6s vs 154s = **25.7× faster**
- Full iteration cycle (code → deploy → test → repeat): **<10 seconds**

**Concrete Use Cases:**
1. **Feature Development:** I'm adding a new "cache warming" feature. I need to test it works before committing.
   - LocalStack: 20 iterations in 2 minutes
   - AWS: 20 iterations in 50 minutes

2. **Bug Fixing:** Singleflight isn't preventing duplicate DB queries.
   - LocalStack: Fix → test → verify in 15 seconds
   - AWS: Fix → wait 2.5 minutes → test → wait again

3. **CI/CD Pipeline Validation:** GitHub Actions runs my integration tests.
   - LocalStack: Pipeline completes in 3 minutes
   - AWS: Pipeline takes 15 minutes + requires AWS credentials

---

### **✅ Scenario 2: Cost-Constrained Development**

**Evidence:**
- LocalStack: $0/hour
- AWS Learner Lab: $100 credits (depletes in 20 days of 24/7 usage)

**Concrete Use Cases:**
1. **Student Projects:** I have limited AWS credits. I use LocalStack for 80% of development.
2. **Open-Source Development:** Community contributors can test locally without AWS accounts.
3. **Extended Learning:** I spent 3 weeks experimenting with Raft consensus. LocalStack cost: $0.

---

### **✅ Scenario 3: Offline Development**

**Evidence:**
- LocalStack runs entirely on `localhost`
- No internet required after initial Docker image pull

**Concrete Use Cases:**
1. **Travel/Remote Work:** Coding on a plane with no WiFi.
2. **Security-Sensitive Development:** Government/enterprise environments where AWS access is restricted.

---

### **✅ Scenario 4: CI/CD Integration**

**Evidence:**
- Fast execution: 6s deployment
- No AWS credentials in CI environment (better security)

**Example GitHub Actions Workflow:**
```yaml
- name: Start LocalStack
  run: docker-compose up -d
- name: Deploy Cache Cluster
  run: terraform apply -auto-approve
- name: Run Integration Tests
  run: ./test.sh
# Total time: 3 minutes
```

---

**[SLIDE: Use AWS Real When...]**

### **✅ Scenario 1: Performance Validation**

**Evidence:**
- Network Latency:
  - LocalStack: 10-50ms (simulated)
  - AWS Real: 1-5ms (same VPC, actual containers)
- Service Discovery:
  - LocalStack: 754-2304ms (degrading simulation)
  - AWS Real: 100-300ms (consistent, real Cloud Map)

**Concrete Use Cases:**
1. **Load Testing:** I need to validate the system handles 50,000 requests/second.
   - AWS Real: Accurate latency percentiles (P50, P95, P99)
   - LocalStack: Unrealistic due to simulated network

2. **Capacity Planning:** How many nodes do I need for Black Friday traffic?
   - AWS Real: Test with real ECS scaling, real ALB distribution
   - LocalStack: Cannot accurately predict resource limits

3. **Performance Benchmarking:** Which is faster: gRPC or HTTP for inter-node communication?
   - AWS Real: Measure actual network overhead
   - LocalStack: Simulated, not trustworthy

---

### **✅ Scenario 2: Production Readiness Validation**

**Evidence:**
- Observability: 51 log streams, 63 metrics vs 0
- Multi-AZ deployment: RDS failover works
- IAM roles: Actual AWS permissions vs LocalStack stubs

**Concrete Use Cases:**
1. **Weekly Integration Tests:** Every Friday, I deploy to AWS Real to catch integration issues.
   - Example: LocalStack's Cloud Map didn't register instances → caught in AWS.

2. **Monitoring Setup:** Validate Grafana dashboards pull real CloudWatch metrics.
   - AWS Real: See actual `CpuUtilized` spikes
   - LocalStack: No metrics to graph

3. **Disaster Recovery Testing:** Simulate AZ failure.
   - AWS Real: RDS auto-failover works in 30 seconds
   - LocalStack: Cannot test Multi-AZ behavior

---

### **✅ Scenario 3: Scalability Testing**

**Evidence:**
- LocalStack: Only simulates containers, cannot test resource exhaustion
- AWS Real: Actual Fargate task limits, actual memory/CPU pressure

**Concrete Use Cases:**
1. **Horizontal Scaling Limits:** What happens at 50 Fargate tasks?
   - AWS Real: Hit service quota, request limit increase
   - LocalStack: No limits enforced

2. **Auto-Scaling Policy Tuning:** When should I scale up?
   - AWS Real: Test with real CloudWatch alarms (>70% CPU → add node)
   - LocalStack: Alarms don't trigger realistically

---

## **REAL-WORLD WORKFLOW** (1.5 minutes)

**[SLIDE: Recommended Development Workflow]**

Based on my 3-month project, here's the optimal workflow:

### **Phase 1: Development (80% of time)**
**Environment: LocalStack**

**Daily Routine:**
```bash
# Morning: Start LocalStack
docker-compose up -d

# Develop feature
vim geecache/cache.go

# Test (25.7× faster than AWS)
terraform apply -auto-approve  # 6 seconds
curl http://localhost:9999/api?key=Tom

# Iterate quickly
# (20-30 deploys per day × 6s = 3 minutes total)
```

**Benefits:**
- Zero AWS costs
- Instant feedback
- Offline-capable

---

### **Phase 2: Weekly Validation (15% of time)**
**Environment: AWS Real**

**Friday Afternoon:**
```bash
# Deploy to AWS Learner Lab
cd aws-terraform
terraform apply  # 154 seconds (acceptable once/week)

# Run comprehensive tests
./benchmark.sh

# Validate:
# ✅ CloudWatch metrics appear
# ✅ Service discovery works
# ✅ Multi-AZ RDS failover
# ✅ Latency < 5ms

# Teardown to save credits
terraform destroy
```

**Benefits:**
- Catch LocalStack divergence early
- Validate production readiness
- Test observability stack

---

### **Phase 3: Production (5% of time)**
**Environment: AWS Real (with proper monitoring)**

**Deployment:**
```bash
# Use production-grade Terraform
# - Enable Container Insights
# - Configure CloudWatch alarms
# - Set up Grafana dashboards
# - Enable RDS Multi-AZ

terraform apply -var="env=prod"
```

**Post-Deployment:**
- Monitor 51 log streams
- Track 63 CloudWatch metrics
- Set alerts for:
  - Cache hit rate < 85%
  - P99 latency > 50ms
  - Database QPS > 5000 (8% cache miss rate)

---

## **LIMITATIONS & FUTURE WORK** (1 minute)

**[SLIDE: Limitations Discovered]**

### **LocalStack Gaps I Found:**

1. **Cloud Map Service Discovery:**
   - Status: Instances not registering
   - Impact: Cannot test service mesh features
   - Workaround: Use ECS API-based discovery

2. **Container Insights:**
   - Status: 0 metrics available
   - Impact: Cannot test observability locally
   - Workaround: Mock metrics in development

3. **Multi-AZ Simulation:**
   - Status: No AZ failure simulation
   - Impact: Cannot test disaster recovery
   - Workaround: Test only on AWS Real

### **Future Enhancements:**

1. **Kafka Integration (Phase 4):**
   - Add cache invalidation via Kafka events
   - Test in AWS Real only (LocalStack's MSK incomplete)

2. **Cross-Region Replication:**
   - Deploy to `us-west-2` for global users
   - LocalStack doesn't support multi-region

3. **Cost Optimization:**
   - Use AWS Spot instances (70% cheaper)
   - Test locally in LocalStack first

---

## **CONCLUSIONS** (1 minute)

**[SLIDE: Key Takeaways]**

### **The Data-Driven Answer:**

**LocalStack is ideal for:**
- ✅ Development (25× faster iteration)
- ✅ Cost savings ($0 vs $144/month)
- ✅ CI/CD integration
- ✅ Offline development

**AWS Real is essential for:**
- ✅ Performance validation (10× more realistic latency)
- ✅ Production readiness (51 log streams, 63 metrics)
- ✅ Scalability testing
- ✅ Disaster recovery testing

### **My Recommended Split:**
- **80% LocalStack** (daily development)
- **15% AWS Real** (weekly validation)
- **5% AWS Real** (production deployment with monitoring)

### **ROI Calculation:**
- Development time saved: 148 seconds/deploy × 30 deploys/day = **74 minutes/day**
- Cost saved: $144/month (student budget)
- Quality maintained: Weekly AWS validation catches 100% of LocalStack divergences

---

## **Q&A** (remaining time)

**[SLIDE: Thank You + GitHub Link]**

Thank you for your attention. I'm happy to answer questions about:
- The distributed caching architecture
- Benchmark methodology
- Specific LocalStack vs AWS differences
- How to replicate these results

**GitHub Repository:**
https://github.com/yufei-ilariahuang/Distributed-Caching-Optimization

All code, Terraform configs, and benchmark scripts are open-source.

---

## **APPENDIX: Backup Slides**

### **Backup Slide 1: Cache Breakdown Example**

**Without Singleflight:**
```
100 requests for "Nike Shoes" → 100 DB queries → DB crash
```

**With Singleflight:**
```go
// Only first request hits DB
g.Do("Nike Shoes", func() (interface{}, error) {
    return db.Query("SELECT * FROM products WHERE id=?", key)
})
// Other 99 requests wait and share result
```

**Evidence from Logs:**
```
# Before singleflight:
[SlowDB] search key Tom
[SlowDB] search key Tom  # ❌ Duplicate query
[SlowDB] search key Tom  # ❌ Duplicate query

# After singleflight:
[SlowDB] search key Tom  # ✅ Only one query
[GeeCache] hit
[GeeCache] hit
```

---

### **Backup Slide 2: Consistent Hashing Visual**

```
Hash Ring (2^32 space):

    Node A (hash: 12345)
         ↓
    ●───────────────●
   ↑                 ↓
  Tom              Node B (hash: 67890)
(hash: 45678)       
   ↑                 ↓
    ●───────────────●
         ↑
    Node C (hash: 98765)

Rule: Key goes to first node clockwise
Tom (45678) → Node B (67890)
```

**What happens when Node B fails?**
- Old: Tom → Node B
- New: Tom → Node C (next clockwise)
- Only keys between Node A and Node B get remapped (~33%)

**With Virtual Nodes (150 per real node):**
- More even distribution
- Only ~10% of keys remapped when node fails

---

### **Backup Slide 3: Cost Breakdown**

**AWS Real Environment (24/7 operation):**
```
- Application Load Balancer: $16.20/month
- ECS Fargate (3 tasks, 0.5 vCPU, 1GB): $32.40/month
- RDS PostgreSQL (db.t3.micro, Multi-AZ): $30.00/month
- CloudWatch Logs/Metrics: $5.00/month
- Data Transfer: $10.00/month
──────────────────────────────────────
Total: $93.60/month (production)
```

**LocalStack Environment:**
```
- Laptop electricity: ~$2/month
- Internet: $0 (already have)
──────────────────────────────────────
Total: $2/month

Savings: $91.60/month = $1,099.20/year
```

For a student with $100 AWS credits:
- AWS Real: Credits last 1 month
- LocalStack: Credits last indefinitely (use only for validation)

---

