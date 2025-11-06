# General Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "Evolve AI Infra"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones (empty to use first N available)"
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for cost savings (not recommended for production)"
  type        = bool
  default     = true
}

# EKS Cluster Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

# General Node Group Configuration
variable "general_node_instance_types" {
  description = "Instance types for general purpose node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "general_node_desired_size" {
  description = "Desired number of nodes in general purpose node group"
  type        = number
  default     = 2
}

variable "general_node_min_size" {
  description = "Minimum number of nodes in general purpose node group"
  type        = number
  default     = 1
}

variable "general_node_max_size" {
  description = "Maximum number of nodes in general purpose node group"
  type        = number
  default     = 4
}

# GPU Node Group Configuration
variable "enable_gpu_nodes" {
  description = "Enable GPU node group for ML workloads"
  type        = bool
  default     = false
}

variable "gpu_node_instance_types" {
  description = "GPU instance types (will use spot instances)"
  type        = list(string)
  default     = ["g5.xlarge", "g5.2xlarge"]
}

variable "gpu_node_desired_size" {
  description = "Desired number of GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_node_min_size" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum number of GPU nodes"
  type        = number
  default     = 2
}
