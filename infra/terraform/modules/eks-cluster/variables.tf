variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for EKS control plane"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

# Cluster Configuration
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
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# General Node Group Configuration
variable "enable_general_nodes" {
  description = "Enable general node group for standard workloads"
  type        = bool
  default     = false
}
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

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
