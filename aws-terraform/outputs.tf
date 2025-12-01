output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = aws_ecr_repository.geecache.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.geecache_cluster.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.geecache_vpc.id
}

output "note_service_discovery" {
  description = "Note about service discovery"
  value       = "Cloud Map not available in Learner Lab - using direct ECS task IPs"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.geecache_logs.name
}

output "cache_node_service_name" {
  description = "Cache node service name"
  value       = aws_ecs_service.geecache_nodes.name
}

output "api_service_name" {
  description = "API service name"
  value       = aws_ecs_service.geecache_api.name
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.geecache_sg.id
}
