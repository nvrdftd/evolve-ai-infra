variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repositories allowed to assume this role (format: repo:owner/repo:*)"
  type        = list(string)
}

variable "iam_policy_arns" {
  description = "List of IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "custom_policy_json" {
  description = "Custom IAM policy JSON to attach to the role"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
