# Distributed Caching System - Deployment Comparison

## Project Structure

```
.
├── docker-native/          # Simple Docker setup (etcd-based)
│   ├── docker-compose.yml  # All services
│   ├── benchmark.sh        # Performance tests
│   ├── TESTING.md          # Testing guide
│   └── README.md
│
├── localstack-setup/       # LocalStack ECS deployment (AWS-like)
│   ├── docker-compose.yml  # LocalStack + monitoring
│   ├── deploy.sh           # Deploy to LocalStack ECS
│   ├── test.sh             # Test LocalStack deployment
│   └── README.md
│
└── (source code files)     # Shared by both deployments
```

## Quick Start Guide

### Option 1: Docker Native (Recommended for Local Testing)
```bash
cd docker-native
LOCALSTACK_AUTH_TOKEN="ls-WeRacONi-BACo-2137-PEga-kedo6393c02e" docker compose up -d
./benchmark.sh
```

### Option 2: AWS Learner Lab (For Cloud Comparison)
See AWS deployment guide (coming next)

### ~~Option 3: LocalStack~~ (Not Recommended)
LocalStack Free tier doesn't support ECS Fargate, Cloud Map, or ECR - the key services needed for this comparison.

## Comparison Matrix

| Aspect | Docker Native | LocalStack | AWS Learner Lab |
|--------|--------------|------------|-----------------|
| **Service Discovery** | etcd | Cloud Map (simulated) | Cloud Map (real) |
| **Orchestration** | Docker Compose | ECS (simulated) | ECS (real) |
| **Setup Time** | 15-30s | 2-3 min | 5-10 min |
| **Cost** | Free | Free | Free (limited hours) |
| **Realism** | Low | Medium | High |
| **Network Latency** | ~1-10ms | ~10-50ms | ~50-200ms |
| **Best For** | Quick testing | AWS practice | Production-like |

## Testing Metrics

Both setups measure:
1. Network latency between cache nodes
2. Cache hit rate under various loads
3. Service discovery overhead
4. Deployment complexity & time
5. Horizontal scalability limits

## Next Steps

1. **Run docker-native tests** - Establish baseline metrics
2. **Run localstack tests** - Compare AWS-like architecture
3. **Deploy to AWS Learner Lab** - Get production metrics
4. **Analyze results** - Document pros/cons of each approach
