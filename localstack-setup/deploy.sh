#!/bin/bash
# LocalStack Setup Script - Deploy GeeCache to LocalStack ECS

set -e

LOCALSTACK_ENDPOINT="http://localhost:4566"
AWS="aws --endpoint-url=$LOCALSTACK_ENDPOINT --region us-east-1"

echo "=== LocalStack GeeCache Deployment ==="
echo "Note: Using local Docker images (ECR requires LocalStack Pro)"
echo ""

# Step 1: Build Docker image locally
echo "🐳 Step 1: Building Docker image..."
cd ..
docker build -f docker-native/Dockerfile -t geecache:latest .
echo ""

# Step 2: Create ECS cluster
echo "🏗️  Step 2: Creating ECS cluster..."
$AWS ecs create-cluster --cluster-name geecache-cluster 2>/dev/null || echo "Cluster already exists"
echo ""

# Step 3: Create Cloud Map namespace for service discovery
echo "🔍 Step 3: Creating Cloud Map namespace..."
$AWS servicediscovery create-private-dns-namespace \
  --name geecache.local \
  --vpc vpc-12345 \
  --description "GeeCache service discovery" 2>/dev/null || echo "Namespace already exists"

NAMESPACE_ID=$($AWS servicediscovery list-namespaces --query "Namespaces[?Name=='geecache.local'].Id" --output text 2>/dev/null)
echo "Namespace ID: $NAMESPACE_ID"
echo ""

# Step 4: Create Cloud Map service
echo "🔍 Step 4: Creating Cloud Map service..."
$AWS servicediscovery create-service \
  --name cache-nodes \
  --namespace-id $NAMESPACE_ID \
  --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" 2>/dev/null || echo "Service already exists"

SERVICE_ID=$($AWS servicediscovery list-services --query "Services[?Name=='cache-nodes'].Id" --output text 2>/dev/null)
echo "Service ID: $SERVICE_ID"
echo ""

# Step 5: Register task definition (using local Docker image)
echo "📋 Step 5: Registering ECS task definition..."
cat > task-definition.json <<EOF
{
  "family": "geecache-task",
  "networkMode": "bridge",
  "containerDefinitions": [
    {
      "name": "geecache",
      "image": "geecache:latest",
      "memory": 512,
      "cpu": 256,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8001,
          "hostPort": 8001,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DISCOVERY_TYPE",
          "value": "cloudmap"
        }
      ]
    }
  ],
  "requiresCompatibilities": ["EC2"]
}
EOF

$AWS ecs register-task-definition --cli-input-json file://task-definition.json
echo ""

# Step 6: Create ECS service with Cloud Map integration
echo "🚀 Step 6: Creating ECS service with Cloud Map (3 tasks)..."
$AWS ecs create-service \
  --cluster geecache-cluster \
  --service-name geecache-service \
  --task-definition geecache-task \
  --desired-count 3 \
  --service-registries "registryArn=arn:aws:servicediscovery:us-east-1:000000000000:service/$SERVICE_ID" 2>/dev/null || echo "Service already exists"
echo ""

# Step 7: Create CloudWatch Log Group
echo "📊 Step 7: Creating CloudWatch log group..."
$AWS logs create-log-group --log-group-name /ecs/geecache 2>/dev/null || echo "Log group already exists"
echo ""

echo "=== Deployment Complete! ==="
echo ""
echo "Verify deployment:"
echo "  $AWS ecs list-tasks --cluster geecache-cluster"
echo "  $AWS ecs describe-tasks --cluster geecache-cluster --tasks <task-arn>"
echo ""
echo "Check Cloud Map service discovery:"
echo "  $AWS servicediscovery list-services"
echo "  $AWS servicediscovery discover-instances --namespace-name geecache.local --service-name cache-nodes"
echo ""
echo "View logs:"
echo "  $AWS logs tail /ecs/geecache --follow"
echo ""
echo "View logs:"
echo "  $AWS logs tail /ecs/geecache --follow"
echo ""
echo "Note: LocalStack simulates AWS - actual functionality may vary"
