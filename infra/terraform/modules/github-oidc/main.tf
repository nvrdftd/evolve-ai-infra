# GitHub OIDC Provider for AWS
# This allows GitHub Actions to authenticate with AWS without storing credentials

# Create the OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # GitHub's thumbprint - this is the current valid thumbprint
  # Source: https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = var.tags
}

# IAM Role that GitHub Actions will assume
resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  description        = "Role for GitHub Actions to deploy infrastructure"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = var.tags
}

# Trust policy for the IAM role
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_repositories
    }
  }
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "github_actions_policies" {
  for_each = toset(var.iam_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

# Optional: Create a custom policy for specific permissions
resource "aws_iam_role_policy" "github_actions_custom" {
  count = var.custom_policy_json != "" ? 1 : 0

  name   = "${var.role_name}-custom-policy"
  role   = aws_iam_role.github_actions.id
  policy = var.custom_policy_json
}