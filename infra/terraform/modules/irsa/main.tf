terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# IAM Policy Document for IRSA Assume Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# IAM Role for Service Account
resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    var.tags,
    {
      ServiceAccount = "${var.namespace}/${var.service_account_name}"
    }
  )
}

# Attach AWS Managed Policies
resource "aws_iam_role_policy_attachment" "managed_policies" {
  for_each = toset(var.aws_managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Create and Attach Custom IAM Policy
resource "aws_iam_policy" "custom" {
  count = var.custom_policy_json != null ? 1 : 0

  name        = "${var.role_name}-custom-policy"
  description = "Custom policy for ${var.role_name}"
  policy      = var.custom_policy_json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = var.custom_policy_json != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.custom[0].arn
}
