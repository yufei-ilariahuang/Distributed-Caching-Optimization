# LocalStack vs AWS Structure Comparison

### LocalStack (etcd-based)
```bash
Docker Compose on localhost:
├── LocalStack container (port 4566)
│   ├── Simulated EC2/ECS/EKS
│   ├── Simulated ALB
│   └── Simulated CloudWatch
├── Kubernetes (minikube/kind)
│   ├── GeeCache pods (3 replicas) ──┐
│   ├── etcd StatefulSet ─────────────┼─→ Service Discovery
│   ├── API frontend pod ─────────────┘
│   └── Prometheus (scrapes metrics)
├── Grafana (port 3000)
│   └── Dashboards: cache hit rate, latency, throughput
└── etcd cluster (port 2379)
    └── Service registry for peer discovery

Discovery: Nodes query etcd directly for peer locations
Monitoring: Prometheus → Grafana (real-time metrics visualization)
```
### AWS (ECS Service Discovery)
```bash
AWS Cloud:
├── VPC
│   ├── ALB (public-facing)
│   ├── ECS Cluster
│   │   ├── Task: GeeCache node 1 ──┐
│   │   ├── Task: GeeCache node 2 ──┼─→ Auto-register with
│   │   ├── Task: GeeCache node 3 ──┘    Cloud Map (AWS Service Discovery)
│   │   └── Task: API frontend
│   ├── Cloud Map (Service Discovery)
│   │   └── DNS namespace: geecache.local
│   └── CloudWatch (metrics/logs)

Discovery: Nodes use DNS lookups (node1.geecache.local)
NO etcd needed - AWS manages it
```