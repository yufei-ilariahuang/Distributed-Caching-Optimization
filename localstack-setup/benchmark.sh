#!/bin/bash
# LocalStack Benchmark Script

AWS="aws --endpoint-url=http://localhost:4566 --region us-east-1"

echo "=== LocalStack GeeCache Benchmark ==="
echo ""

# Test 1: Deployment Time
echo "📊 Test 1: Deployment Time"
echo "Redeploying service..."
START=$(date +%s)
$AWS ecs update-service --cluster geecache-cluster --service geecache-service --force-new-deployment > /dev/null 2>&1
sleep 5
# Wait for tasks to be running
while [ $($AWS ecs describe-services --cluster geecache-cluster --services geecache-service --query "services[0].runningCount" --output text) -lt 3 ]; do
    sleep 2
done
END=$(date +%s)
DEPLOY_TIME=$((END - START))
echo "Deployment time: ${DEPLOY_TIME}s"
echo ""


# Test 2: ECS Task Count & Distribution
echo "📊 Test 3: Scalability - Current Task Distribution"
TASKS=$($AWS ecs list-tasks --cluster geecache-cluster --query "taskArns[*]" --output text)
TASK_COUNT=$(echo $TASKS | wc -w | tr -d ' ')
echo "Running tasks: $TASK_COUNT"
$AWS ecs describe-tasks --cluster geecache-cluster --tasks $TASKS --query "tasks[*].[taskArn,lastStatus,containers[0].name]" --output table
echo ""

# Test 3: Scale up test
echo "📊 Test 4: Horizontal Scalability - Scale to 5 nodes"
START=$(date +%s)
$AWS ecs update-service --cluster geecache-cluster --service geecache-service --desired-count 5 > /dev/null 2>&1
sleep 3
while [ $($AWS ecs describe-services --cluster geecache-cluster --services geecache-service --query "services[0].runningCount" --output text) -lt 5 ]; do
    sleep 2
done
END=$(date +%s)
SCALE_TIME=$((END - START))
echo "Scale-up time (3→5 nodes): ${SCALE_TIME}s"

# Scale back down
$AWS ecs update-service --cluster geecache-cluster --service geecache-service --desired-count 3 > /dev/null 2>&1
echo ""

# Test 4: Cloud Map instance registration
echo "📊 Test 5: Service Discovery - Registered Instances"
$AWS servicediscovery discover-instances \
    --namespace-name geecache.local \
    --service-name cache-nodes \
    --query "Instances[*].[InstanceId,Attributes]" \
    --output table 2>/dev/null || echo "Instances not yet registered"
echo ""


# Test 5: Network latency (simulated - LocalStack doesn't run actual containers)
echo "📊 Test 7: Network Latency Estimate"
echo "Note: LocalStack ECS tasks are simulated, not real containers"
echo "Expected latency in real AWS: 1-5ms (same VPC)"
echo "LocalStack API response time: ~10-50ms"
echo ""

