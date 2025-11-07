output "ebs_csi_driver_iam_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "ebs_csi_driver_addon_version" {
  description = "Version of the EBS CSI driver addon"
  value       = var.enable_ebs_csi_driver ? aws_eks_addon.ebs_csi_driver[0].addon_version : null
}

output "vpc_cni_addon_version" {
  description = "Version of the VPC CNI addon"
  value       = var.enable_vpc_cni ? aws_eks_addon.vpc_cni[0].addon_version : null
}

output "coredns_addon_version" {
  description = "Version of the CoreDNS addon"
  value       = var.enable_coredns ? aws_eks_addon.coredns[0].addon_version : null
}

output "kube_proxy_addon_version" {
  description = "Version of the kube-proxy addon"
  value       = var.enable_kube_proxy ? aws_eks_addon.kube_proxy[0].addon_version : null
}
