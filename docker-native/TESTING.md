# LocalStack Testing Guide

## Quick Start

```bash
# 1. Start the stack
LOCALSTACK_AUTH_TOKEN="ls-WeRacONi-BACo-2137-PEga-kedo6393c02e" docker compose up -d

# 2. Wait for services (10 seconds)
sleep 10

# 3. Run benchmark
chmod +x benchmark.sh
./benchmark.sh
```

## What Gets Tested

### 1. Network Latency (Target: <10ms)
- Measures round-trip time between cache nodes
- Docker network overhead
- **View**: Check terminal output for ms values

### 2. Cache Hit Rate (Target: >80%)
- Send 100 mixed requests (repeated keys)
- Calculate hits/(hits+misses) ratio
- **View**: Terminal shows percentage

### 3. Service Discovery Overhead (Target: <5ms)
- Time to query etcd for peer locations
- Discovery registration time
- **View**: Terminal shows lookup times

### 4. Deployment Time (Target: <30s)
- Full stack teardown and startup
- Service health checks
- **View**: Terminal shows total seconds

### 5. Horizontal Scalability
- Load distribution across 3 nodes
- Concurrent request handling
- **View**: Requests per node in terminal

## Manual Testing

### Test Cache Hit Rate
```bash
# Warm up
curl "http://localhost:9999/api?key=Tom"
curl "http://localhost:9999/api?key=Jack"

# Check metrics
curl -s "http://localhost:9999/metrics" | grep geecache_hits
curl -s "http://localhost:9999/metrics" | grep geecache_misses
```

### Test Network Latency
```bash
# Time a request
time curl "http://localhost:8001/_geecache/scores/Tom"
```

### Test Service Discovery
```bash
# Query etcd
docker exec etcd etcdctl get --prefix ""
```

### Test Scalability
```bash
# Check node metrics
curl -s "http://localhost:8001/metrics" | grep requests_total
curl -s "http://localhost:8002/metrics" | grep requests_total
curl -s "http://localhost:8003/metrics" | grep requests_total
```

## View Results

1. **Grafana Dashboards**: http://localhost:3000 (admin/admin)
   - GeeCache Performance Dashboard
   - Container Resources Dashboard

2. **Prometheus Metrics**: http://localhost:9090
   - Query: `geecache_hits_total`
   - Query: `geecache_request_duration_seconds`
   - Query: `rate(geecache_requests_total[1m])`

3. **Container Stats**: http://localhost:8080 (cAdvisor)

## Expected Results (LocalStack)

| Metric | Expected Value | Notes |
|--------|---------------|-------|
| Network Latency | 1-10ms | Docker network overhead |
| Cache Hit Rate | 80-95% | With repeated keys |
| etcd Lookup | 1-5ms | Local etcd cluster |
| Deployment Time | 15-30s | Full stack startup |
| Scalability | Linear | 3 nodes handle 3x load |

## Comparison Points for AWS

When you deploy to AWS Learner Lab, compare:

- **Latency**: AWS will be higher (~10-50ms) due to internet/VPC
- **Hit Rate**: Should be similar (80-95%)
- **Discovery**: Cloud Map DNS faster than etcd (~<1ms)
- **Deployment**: AWS slower (2-5 min for ECS tasks)
- **Scalability**: AWS auto-scaling vs manual Docker scaling
