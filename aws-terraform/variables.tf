variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "cache_node_count" {
  description = "Number of cache nodes to deploy"
  type        = number
  default     = 3
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "geecache"
}
