#!/bin/bash
# AWS Deployment Script for GeeCache
set -e

echo "=== AWS GeeCache Deployment ==="
echo ""

# Configuration
REGION=${AWS_REGION:-us-east-1}
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_DIR}/aws-terraform"


# Step 1: Check prerequisites
print_step "Step 1: Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { print_error "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v terraform >/dev/null 2>&1 || { print_error "Terraform is required but not installed. Aborting."; exit 1; }
command -v docker >/dev/null 2>&1 || { print_error "Docker is required but not installed. Aborting."; exit 1; }

# Check AWS credentials
aws sts get-caller-identity > /dev/null 2>&1 || { print_error "AWS credentials not configured. Run 'aws configure'. Aborting."; exit 1; }
echo "✓ AWS credentials configured"
echo "✓ All prerequisites met"
echo ""

# Step 2: Initialize Terraform
print_step "Step 2: Initializing Terraform..."
cd "${TERRAFORM_DIR}"
terraform init
echo ""

# Step 3: Plan Terraform deployment
print_step "Step 3: Planning infrastructure deployment..."
terraform plan -out=tfplan
echo ""

# Step 4: Apply Terraform (with confirmation)
print_step "Step 4: Deploying infrastructure..."
read -p "Do you want to apply the Terraform plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Deployment cancelled by user."
    exit 0
fi

DEPLOY_START=$(date +%s)
terraform apply tfplan
DEPLOY_END=$(date +%s)
DEPLOY_TIME=$((DEPLOY_END - DEPLOY_START))
echo "Infrastructure deployment time: ${DEPLOY_TIME}s"
echo ""

# Step 5: Get outputs
print_step "Step 5: Retrieving deployment outputs..."
ECR_REPO=$(terraform output -raw ecr_repository_url)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
echo "ECR Repository: $ECR_REPO"
echo "ECS Cluster: $CLUSTER_NAME"
echo ""

# Step 6: Build and push Docker image
print_step "Step 6: Building and pushing Docker image..."
cd "${PROJECT_DIR}"

# Authenticate Docker to ECR
print_step "Authenticating Docker to ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

# Build Docker image
print_step "Building Docker image..."
BUILD_START=$(date +%s)
docker build -t geecache:latest -f docker-native/Dockerfile .
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))
echo "Docker build time: ${BUILD_TIME}s"

# Tag and push image
docker tag geecache:latest ${ECR_REPO}:latest
PUSH_START=$(date +%s)
docker push ${ECR_REPO}:latest
PUSH_END=$(date +%s)
PUSH_TIME=$((PUSH_END - PUSH_START))
echo "Docker push time: ${PUSH_TIME}s"
echo ""

# Step 7: Force ECS service update to pull new image
print_step "Step 7: Updating ECS services..."
UPDATE_START=$(date +%s)
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service geecache-nodes \
    --force-new-deployment \
    --region ${REGION} > /dev/null

aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service geecache-api \
    --force-new-deployment \
    --region ${REGION} > /dev/null

echo "Waiting for services to stabilize..."
aws ecs wait services-stable \
    --cluster ${CLUSTER_NAME} \
    --services geecache-nodes geecache-api \
    --region ${REGION}
UPDATE_END=$(date +%s)
UPDATE_TIME=$((UPDATE_END - UPDATE_START))
echo "Service update time: ${UPDATE_TIME}s"
echo ""

# Step 8: Display running tasks
print_step "Step 8: Deployment summary..."
TASKS=$(aws ecs list-tasks --cluster ${CLUSTER_NAME} --region ${REGION} --query "taskArns" --output text)
TASK_COUNT=$(echo $TASKS | wc -w | tr -d ' ')

echo "=== Deployment Complete ==="
echo "Running tasks: $TASK_COUNT"
echo ""
echo "Timing Summary:"
echo "  Infrastructure deployment: ${DEPLOY_TIME}s"
echo "  Docker build: ${BUILD_TIME}s"
echo "  Docker push: ${PUSH_TIME}s"
echo "  Service update: ${UPDATE_TIME}s"
echo "  Total time: $((DEPLOY_TIME + BUILD_TIME + PUSH_TIME + UPDATE_TIME))s"
echo ""
echo "Next steps:"
echo "  1. Run './benchmark.sh' to test the deployment"
echo "  2. View logs: aws logs tail /ecs/geecache --follow --region ${REGION}"
echo "  3. To destroy: cd aws-terraform && terraform destroy"
