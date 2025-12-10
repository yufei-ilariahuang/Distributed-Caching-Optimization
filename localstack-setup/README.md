# LocalStack Setup (AWS-Compatible)

Deploy GeeCache to LocalStack using ECS (works with your Pro license).

## Prerequisites

```bash
# Install AWS CLI
brew install awscli

# Set LocalStack token (you already have Pro features!)
export LOCALSTACK_AUTH_TOKEN="ls-WeRacONi-BACo-2137-PEga-kedo6393c02e"
```

## Quick Start

```bash
# 1. Start LocalStack
docker compose up -d

# 2. Wait for LocalStack to be ready (30 seconds)
sleep 30

# 3. Deploy GeeCache to LocalStack ECS
./deploy.sh

# 4. Run tests
./test.sh

# or to desdroy and restart
./fix-and-deploy.sh 
```

## What Works with Your LocalStack Pro

✅ **ECS** - Container orchestration
✅ **ECR** - Container registry (but using local images for simplicity)
✅ **CloudWatch** - Logs and metrics
✅ **EC2** - Underlying compute

❌ **Cloud Map** - Not included (using direct ECS task discovery instead)

## Architecture

```
LocalStack (port 4566)
├── ECS Cluster
│   ├── Task 1: GeeCache node :8001
│   ├── Task 2: GeeCache node :8002
│   └── Task 3: GeeCache node :8003
├── CloudWatch
│   └── Logs /ecs/geecache
└── Local Docker Images
    └── geecache:latest
```
