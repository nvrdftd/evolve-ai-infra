output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "custom_policy_arn" {
  description = "ARN of the custom IAM policy (if created)"
  value       = var.custom_policy_json != null ? aws_iam_policy.custom[0].arn : null
}

output "service_account_annotations" {
  description = "Annotations to add to the Kubernetes service account"
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
  }
}
