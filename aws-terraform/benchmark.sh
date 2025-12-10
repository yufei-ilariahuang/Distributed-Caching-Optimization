#!/bin/bash
# AWS Benchmark Script for GeeCache
# Mirrors LocalStack benchmark tests for direct comparison

set -e

REGION=${AWS_REGION:-us-west-2}
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


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

# Test 2: Scalability - Current Task Distribution
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

# Test 3: Horizontal Scalability - Scale to 5 nodes
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

# Test 4: CloudWatch Logs
print_test "Test 6: CloudWatch Logs"
LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name ${LOG_GROUP} \
    --region ${REGION} \
    --query "logStreams[*].logStreamName" \
    --output text 2>/dev/null | wc -w | tr -d ' ')
echo "Log streams available: $LOG_STREAMS"

