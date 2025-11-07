variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  type        = string
}

# EBS CSI Driver
variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver addon for persistent volumes"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon (set to null for latest)"
  type        = string
  default     = null
}

# VPC CNI
variable "enable_vpc_cni" {
  description = "Enable VPC CNI addon"
  type        = bool
  default     = true
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI addon (set to null for latest)"
  type        = string
  default     = null
}

# CoreDNS
variable "enable_coredns" {
  description = "Enable CoreDNS addon"
  type        = bool
  default     = true
}

variable "coredns_version" {
  description = "Version of the CoreDNS addon (set to null for latest)"
  type        = string
  default     = null
}

# kube-proxy
variable "enable_kube_proxy" {
  description = "Enable kube-proxy addon"
  type        = bool
  default     = true
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy addon (set to null for latest)"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
