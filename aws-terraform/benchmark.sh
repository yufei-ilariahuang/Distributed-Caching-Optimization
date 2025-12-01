#!/bin/bash
# AWS Benchmark Script for GeeCache
# Mirrors LocalStack benchmark tests for direct comparison

set -e

REGION=${AWS_REGION:-us-west-2}
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}📊 $1${NC}"
}

# Get Terraform outputs
cd "${TERRAFORM_DIR}"
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "geecache-cluster")
LOG_GROUP=$(terraform output -raw cloudwatch_log_group 2>/dev/null || echo "/ecs/geecache")
CACHE_SERVICE=$(terraform output -raw cache_node_service_name 2>/dev/null || echo "geecache-nodes")
API_SERVICE=$(terraform output -raw api_service_name 2>/dev/null || echo "geecache-api")

echo "=== AWS GeeCache Benchmark ==="
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Test 1: Deployment Time
print_test "Test 1: Deployment Time"
echo "Redeploying service..."
START=$(date +%s)
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${CACHE_SERVICE} \
    --force-new-deployment \
    --region ${REGION} > /dev/null 2>&1

echo "Waiting for service to stabilize..."
aws ecs wait services-stable \
    --cluster ${CLUSTER_NAME} \
    --services ${CACHE_SERVICE} \
    --region ${REGION}
END=$(date +%s)
DEPLOY_TIME=$((END - START))
echo "Deployment time: ${DEPLOY_TIME}s"
echo ""

# Test 2: Service Discovery Overhead (Direct ECS Task Discovery)
print_test "Test 2: Service Discovery Overhead (ECS API - No Cloud Map in Learner Lab)"

if [ -z "$TASKS" ] || [ $TASK_COUNT -eq 0 ]; then
    echo "No tasks running - skipping service discovery test"
else
    for i in {1..5}; do
        START=$(date +%s%N)
        aws ecs describe-tasks \
            --cluster ${CLUSTER_NAME} \
            --tasks $TASKS \
            --region ${REGION} > /dev/null 2>&1
        END=$(date +%s%N)
        LOOKUP=$(( (END - START) / 1000000 ))
        echo "Task lookup $i: ${LOOKUP}ms"
    done
fi
echo ""

# Test 3: Scalability - Current Task Distribution
print_test "Test 3: Scalability - Current Task Distribution"
TASKS=$(aws ecs list-tasks \
    --cluster ${CLUSTER_NAME} \
    --region ${REGION} \
    --query "taskArns[*]" \
    --output text)
TASK_COUNT=$(echo $TASKS | wc -w | tr -d ' ')
echo "Running tasks: $TASK_COUNT"

if [ $TASK_COUNT -gt 0 ]; then
    echo ""
    echo "Task details:"
    aws ecs describe-tasks \
        --cluster ${CLUSTER_NAME} \
        --tasks $TASKS \
        --region ${REGION} \
        --query "tasks[*].[taskArn,lastStatus,containers[0].name]" \
        --output table
fi
echo ""

# Test 4: Horizontal Scalability - Scale to 5 nodes
print_test "Test 4: Horizontal Scalability - Scale to 5 nodes"
CURRENT_COUNT=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${CACHE_SERVICE} \
    --region ${REGION} \
    --query "services[0].desiredCount" \
    --output text)

echo "Current desired count: $CURRENT_COUNT"
echo "Scaling to 5 nodes..."

START=$(date +%s)
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${CACHE_SERVICE} \
    --desired-count 5 \
    --region ${REGION} > /dev/null 2>&1

echo "Waiting for scale-up to complete..."
aws ecs wait services-stable \
    --cluster ${CLUSTER_NAME} \
    --services ${CACHE_SERVICE} \
    --region ${REGION}
END=$(date +%s)
SCALE_TIME=$((END - START))
echo "Scale-up time (${CURRENT_COUNT}→5 nodes): ${SCALE_TIME}s"

# Scale back to original count
echo "Scaling back to $CURRENT_COUNT nodes..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${CACHE_SERVICE} \
    --desired-count $CURRENT_COUNT \
    --region ${REGION} > /dev/null 2>&1
echo ""

# Test 5: Service Discovery - Registered Instances
print_test "Test 5: ECS Task Network Information (No Cloud Map in Learner Lab)"
if [ $TASK_COUNT -gt 0 ]; then
    echo "Task network details:"
    aws ecs describe-tasks \
        --cluster ${CLUSTER_NAME} \
        --tasks $TASKS \
        --region ${REGION} \
        --query "tasks[*].[taskArn,containers[0].networkInterfaces[0].privateIpv4Address,lastStatus]" \
        --output table 2>/dev/null || echo "Unable to fetch task network info"
else
    echo "No tasks running"
fi
echo ""

# Test 6: CloudWatch Logs
print_test "Test 6: CloudWatch Logs"
LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name ${LOG_GROUP} \
    --region ${REGION} \
    --query "logStreams[*].logStreamName" \
    --output text 2>/dev/null | wc -w | tr -d ' ')
echo "Log streams available: $LOG_STREAMS"

if [ $LOG_STREAMS -gt 0 ]; then
    echo ""
    echo "Recent log entries (last 10):"
    LATEST_STREAM=$(aws logs describe-log-streams \
        --log-group-name ${LOG_GROUP} \
        --region ${REGION} \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query "logStreams[0].logStreamName" \
        --output text)
    
    aws logs get-log-events \
        --log-group-name ${LOG_GROUP} \
        --log-stream-name "$LATEST_STREAM" \
        --limit 10 \
        --region ${REGION} \
        --query "events[*].message" \
        --output text 2>/dev/null || echo "Unable to fetch logs"
fi
echo ""

# Test 7: Network Latency (Actual AWS Network)
print_test "Test 7: Network Latency"
echo "Real AWS deployment - actual container network"
echo "Expected latency: 1-5ms (same VPC, same AZ)"
echo "Expected latency: 5-15ms (same VPC, different AZ)"
echo "Cross-region: 50-200ms depending on distance"
echo ""

# Get task IPs for ping test (if possible)
TASK_IPS=$(aws ecs describe-tasks \
    --cluster ${CLUSTER_NAME} \
    --tasks $TASKS \
    --region ${REGION} \
    --query "tasks[*].containers[0].networkInterfaces[0].privateIpv4Address" \
    --output text 2>/dev/null)

if [ -n "$TASK_IPS" ]; then
    echo "Task private IPs: $TASK_IPS"
    echo "(Note: Can only ping from within VPC)"
fi
echo ""

# Test 8: Container Insights Metrics
print_test "Test 8: Container Insights Metrics"
echo "Checking available metrics..."
METRICS=$(aws cloudwatch list-metrics \
    --namespace ECS/ContainerInsights \
    --dimensions Name=ClusterName,Value=${CLUSTER_NAME} \
    --region ${REGION} \
    --query "Metrics[*].MetricName" \
    --output text 2>/dev/null | wc -w | tr -d ' ')
echo "Available Container Insights metrics: $METRICS"

if [ $METRICS -gt 0 ]; then
    echo ""
    echo "Available metrics:"
    aws cloudwatch list-metrics \
        --namespace ECS/ContainerInsights \
        --dimensions Name=ClusterName,Value=${CLUSTER_NAME} \
        --region ${REGION} \
        --query "Metrics[*].MetricName" \
        --output text | tr '\t' '\n' | sort -u
fi
echo ""

# Summary
echo "=== Benchmark Summary ==="
echo "Deployment Time: ${DEPLOY_TIME}s"
echo "Service Discovery: ECS API (Cloud Map N/A in Learner Lab)"
echo "Scalability: ${SCALE_TIME}s to scale ${CURRENT_COUNT}→5 nodes"
echo "Running Tasks: $TASK_COUNT"
echo "Log Streams: $LOG_STREAMS"
echo "Container Insights: $METRICS metrics available"
echo ""
echo "=== Comparison with LocalStack ==="
echo "LocalStack Results (for reference):"
echo "  - Deployment Time: 6s"
echo "  - Service Discovery: 754-2304ms (simulated Cloud Map)"
echo "  - Scale-up: 4s (3→5 nodes, simulated)"
echo "  - Running Tasks: 2 (simulated)"
echo "  - Log Streams: 0 (simulated)"
echo ""
echo "AWS Real Results (current):"
echo "  - Deployment Time: ${DEPLOY_TIME}s"
echo "  - Service Discovery: ECS API-based (no Cloud Map in Learner Lab)"
echo "  - Scale-up: ${SCALE_TIME}s (${CURRENT_COUNT}→5 nodes, real)"
echo "  - Running Tasks: $TASK_COUNT (real containers)"
echo "  - Log Streams: $LOG_STREAMS (real logs)"
echo ""
echo "Key Differences:"
echo "  ✓ AWS: Real containers, actual network latency, production metrics"
echo "  ✓ LocalStack: Faster iteration, no costs, simulated behavior"
echo "  ⚠ Learner Lab: No Cloud Map - using direct ECS task discovery"
