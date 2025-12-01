# Docker Native Setup (etcd-based)

Simple Docker Compose deployment without LocalStack.

## Quick Start

```bash
# Start all services
LOCALSTACK_AUTH_TOKEN="ls-WeRacONi-BACo-2137-PEga-kedo6393c02e" docker compose up -d

# Run tests
./benchmark.sh

# View dashboards
open http://localhost:3000  # Grafana (admin/admin)
```

## Architecture

- **Service Discovery**: etcd
- **Cache Nodes**: 3 Docker containers (ports 8001-8003)
- **Monitoring**: Prometheus + Grafana + cAdvisor
- **LocalStack**: Running but not used (included for future AWS CLI testing)

## Files

- `docker-compose.yml` - Full stack definition
- `prometheus.yml` - Metrics scraping config
- `benchmark.sh` - Automated testing script
- `TESTING.md` - Testing guide
- `grafana/` - Dashboard configurations
