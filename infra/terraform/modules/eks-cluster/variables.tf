variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
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

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cost savings)"
  type        = bool
  default     = true
}

variable "general_node_instance_types" {
  description = "Instance types for general nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "general_node_desired_size" {
  description = "Desired number of general nodes"
  type        = number
  default     = 2
}

variable "general_node_min_size" {
  description = "Minimum number of general nodes"
  type        = number
  default     = 2
}

variable "general_node_max_size" {
  description = "Maximum number of general nodes"
  type        = number
  default     = 4
}

variable "enable_gpu_nodes" {
  description = "Enable GPU node group"
  type        = bool
  default     = false
}

variable "gpu_node_instance_types" {
  description = "GPU instance types (spot)"
  type        = list(string)
  default     = ["g5.xlarge", "g5.2xlarge"]
}

variable "gpu_node_desired_size" {
  description = "Desired GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_node_min_size" {
  description = "Minimum GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum GPU nodes"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}