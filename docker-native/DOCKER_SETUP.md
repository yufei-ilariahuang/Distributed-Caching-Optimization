# Docker Setup for GeeCache

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- LocalStack auth token (set as environment variable)

### Setup

1. **Set your LocalStack token:**
```bash
export LOCALSTACK_AUTH_TOKEN="ls-WeRacONi-BACo-2137-PEga-kedo6393c02e"
```

2. **Build and start all services:**
```bash
docker-compose up --build
```

3. **Access the services:**
- **API Frontend**: http://localhost:9999/api?key=Tom
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **LocalStack**: http://localhost:4566
- **Cache Nodes**: http://localhost:8001, 8002, 8003

### Testing Cache

```bash
# Test cache hit
curl "http://localhost:9999/api?key=Tom"

# Test cache miss
curl "http://localhost:9999/api?key=Unknown"

# Load test (requires apache-bench)
ab -n 10000 -c 100 http://localhost:9999/api?key=Tom
```

### Viewing Metrics

1. Open Grafana: http://localhost:3000
2. Login: admin/admin
3. Navigate to "GeeCache Performance Dashboard"
4. View real-time metrics:
   - Cache hit rate
   - Request latency (p95/p99)
   - Throughput
   - Peer-to-peer requests
   - Memory usage

### Stopping Services

```bash
docker-compose down
```

### Cleanup (including volumes)

```bash
docker-compose down -v
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Stack                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  LocalStack (4566) ─┐                                       │
│                      │                                       │
│  etcd (2379) ────────┼─→ Service Discovery                  │
│                      │                                       │
│  cache-node-1 (8001) ┤                                       │
│  cache-node-2 (8002) ├─→ GeeCache Cluster                   │
│  cache-node-3 (8003) │                                       │
│                      │                                       │
│  api-frontend (9999) ┘                                       │
│                                                              │
│  Prometheus (9090) ──→ Scrapes metrics                      │
│                                                              │
│  Grafana (3000) ─────→ Visualizes metrics                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Next Steps

To add metrics instrumentation to your Go code, you'll need to:

1. Add Prometheus client library to `go.mod`
2. Instrument HTTP handlers with metrics counters
3. Expose `/metrics` endpoint on each cache node

Example metrics to track:
- `geecache_requests_total` - Total requests
- `geecache_hits_total` - Cache hits
- `geecache_misses_total` - Cache misses
- `geecache_request_duration_seconds` - Request latency histogram
- `geecache_cache_entries` - Number of cached entries
- `geecache_cache_bytes` - Memory usage
- `geecache_peer_requests_total` - Peer-to-peer requests
