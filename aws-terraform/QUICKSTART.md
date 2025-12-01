# Quick Start: AWS Terraform Deployment

## ⚠️ AWS Learner Lab Users - Start Here!

If you're using AWS Learner Lab, use this command instead:

```bash
cd aws-terraform
./fix-and-deploy.sh
```

This handles Learner Lab permission restrictions automatically.

---

## Prerequisites Check

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Terraform
terraform --version

# Check Docker
docker --version
docker ps
```

## Deploy to AWS

```bash
# 1. Navigate to terraform directory
cd aws-terraform

# 2. Run deployment (includes build, push, and infrastructure)
./deploy.sh

# 3. Wait 5-10 minutes for complete deployment
```

## Run Benchmarks

```bash
# After deployment completes
./benchmark.sh
```

## View Results

```bash
# View logs
aws logs tail /ecs/geecache --follow --region us-east-1

# Check running tasks
aws ecs list-tasks --cluster geecache-cluster --region us-east-1

# Service discovery
aws servicediscovery discover-instances \
  --namespace-name geecache.local \
  --service-name cache-nodes \
  --region us-east-1
```

## Clean Up (Important!)

```bash
cd aws-terraform
terraform destroy
# Type 'yes' to confirm
```

## Troubleshooting

### LabRole not found
```bash
# Verify LabRole exists
aws iam get-role --role-name LabRole
```

### Docker build fails
```bash
# Build manually from project root
cd ..
docker build -t geecache:latest -f docker-native/Dockerfile .
```

### ECR authentication
```bash
# Re-authenticate to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw ecr_repository_url)
```

## Key Files

- `main.tf` - Infrastructure definition (uses LabRole)
- `variables.tf` - Configuration variables
- `outputs.tf` - Deployment outputs
- `deploy.sh` - Automated deployment script
- `benchmark.sh` - Performance testing script

## Cost Warning

**Running costs:** ~$0.20/hour (~$5/day)

Always destroy resources when not in use:
```bash
terraform destroy
```
