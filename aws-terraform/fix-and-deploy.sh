#!/bin/bash
# Fix and redeploy after Learner Lab permission errors

set -e

echo "=== AWS Learner Lab - Fixed Deployment ==="
echo ""
echo "This script will:"
echo "  1. Clean up failed deployment"
echo "  2. Re-deploy with Learner Lab compatible configuration"
echo "  3. Run benchmarks"
echo ""

REGION=${AWS_REGION:-us-west-2}

# Step 1: Destroy partial resources
echo "🧹 Step 1: Cleaning up partial deployment..."
terraform destroy -auto-approve 2>/dev/null || echo "Nothing to destroy (OK)"
echo ""

# Step 2: Re-initialize (in case state is corrupted)
echo "🔧 Step 2: Re-initializing Terraform..."
rm -rf .terraform .terraform.lock.hcl
terraform init
echo ""

# Step 3: Apply with fixed configuration
echo "🚀 Step 3: Deploying with Learner Lab compatible config..."
echo ""
echo "Key changes:"
echo "  ✅ Removed Cloud Map (not available in Learner Lab)"
echo "  ✅ Using ECS API for task discovery"
echo "  ✅ All services use LabRole (no IAM creation)"
echo ""

terraform plan
echo ""

read -p "Ready to deploy? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

terraform apply -auto-approve

echo ""
echo "✅ Deployment complete!"
echo ""

# Step 4: Get ECR URL for Docker push
ECR_REPO=$(terraform output -raw ecr_repository_url)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)

echo "📦 ECR Repository: $ECR_REPO"
echo "🎯 ECS Cluster: $CLUSTER_NAME"
echo ""

# Step 5: Build and push Docker image
echo "🐳 Building and pushing Docker image..."
cd ..

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

docker build -t geecache:latest -f docker-native/Dockerfile .
docker tag geecache:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest

echo ""
echo "✅ Image pushed to ECR"
echo ""

# Step 6: Update ECS services
cd aws-terraform
echo "🔄 Updating ECS services with new image..."

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

echo "Waiting for services to stabilize (this may take 3-5 minutes)..."
aws ecs wait services-stable \
    --cluster ${CLUSTER_NAME} \
    --services geecache-nodes geecache-api \
    --region ${REGION}

echo ""
echo "✅ Services running!"
echo ""

# Step 7: Run benchmarks
echo "📊 Running benchmarks..."
./benchmark.sh

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "  1. Review benchmark results above"
echo "  2. Compare with LocalStack (see DEPLOYMENT_COMPARISON.md)"
echo "  3. Update your comparison document with AWS results"
echo "  4. When done testing: terraform destroy"
echo ""
echo "Note: See LEARNER_LAB_NOTES.md for details on limitations"
