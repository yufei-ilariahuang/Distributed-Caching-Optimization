# Distributed Cache Infrastructure

## Quick Start
```bash
# Start all services
LOCALSTACK_AUTH_TOKEN="ls-WeRacONi-BACo-2137-PEga-kedo6393c02e" docker compose up -d

# Test cache
curl "http://localhost:9999/api?key=Tom"

# View metrics
open http://localhost:3000  # Grafana (admin/admin)
```

## Running Services
- **Cache Nodes**: 8001, 8002, 8003
- **API**: 9999
- **Grafana**: 3000
- **Prometheus**: 9090
- **cAdvisor**: 8080
- **etcd**: 2379
- **LocalStack**: 4566

## Architecture

**LocalStack (Docker)**
- etcd for service discovery
- 3 cache nodes + API frontend
- Prometheus + Grafana + cAdvisor monitoring

**AWS (Learner Lab)**
- ECS with Cloud Map service discovery
- CloudWatch for monitoring
- No etcd needed (AWS-managed DNS)