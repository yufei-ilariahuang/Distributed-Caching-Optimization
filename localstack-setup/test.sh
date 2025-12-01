#!/bin/bash
# Test LocalStack deployment

AWS="aws --endpoint-url=http://localhost:4566 --region us-east-1"

echo "=== LocalStack Deployment Test ==="
echo ""

# Test 1: Verify ECS cluster
echo "📊 Test 1: ECS Cluster Status"
$AWS ecs describe-clusters --clusters geecache-cluster --query "clusters[0].[clusterName,status,runningTasksCount]" --output table
echo ""

# Test 2: List running tasks
echo "📊 Test 2: Running Tasks"
TASKS=$($AWS ecs list-tasks --cluster geecache-cluster --query "taskArns[*]" --output text)
TASK_COUNT=$(echo $TASKS | wc -w | tr -d ' ')
echo "Found $TASK_COUNT tasks running"
echo ""

# Test 3: Cloud Map service discovery
echo "📊 Test 3: Cloud Map Service Discovery"
$AWS servicediscovery list-services --query "Services[*].[Name,Id,InstanceCount]" --output table
echo ""

# Test 4: Discover instances via Cloud Map
echo "📊 Test 4: Discover Cache Node Instances"
$AWS servicediscovery discover-instances \
  --namespace-name geecache.local \
  --service-name cache-nodes \
  --query "Instances[*].[InstanceId,Attributes]" \
  --output table 2>/dev/null || echo "No instances registered yet (may take a moment)"
echo ""

# Test 5: CloudWatch metrics
echo "📊 Test 5: CloudWatch Log Groups"
$AWS cloudwatch list-metrics --namespace ECS/ContainerInsights --query "Metrics[*].MetricName" --output table
echo ""

# Test 5: Deployment time (recreate service)
echo "📊 Test 5: Deployment Time"
START=$(date +%s)
$AWS ecs update-service --cluster geecache-cluster --service geecache-service --desired-count 0 > /dev/null
sleep 2
$AWS ecs update-service --cluster geecache-cluster --service geecache-service --desired-count 3 > /dev/null
END=$(date +%s)
DEPLOY_TIME=$((END - START))
echo "Service update time: ${DEPLOY_TIME}s"
echo ""

echo "=== Test Complete ==="
echo "View in LocalStack: http://localhost:4566/_localstack/health"
