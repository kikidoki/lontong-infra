# The role the APP repo's GitHub Actions assume (OIDC, no stored keys). Scoped to one repo + one GitHub environment,
# and to exactly: its ECR repository, this one Lambda function, and the direct database URL parameter.

variable "name" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "environment" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "function_arn" {
  type = string
}

variable "ssm_path_prefix" {
  type = string
}

variable "allow_image_push" {
  type    = bool
  default = true # staging builds; production only promotes an image that already exists
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${var.environment}"]
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "EcrRead"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability", "ecr:DescribeImages"]
    resources = [var.ecr_repository_arn]
  }

  dynamic "statement" {
    for_each = var.allow_image_push ? [1] : []
    content {
      sid       = "EcrPush"
      actions   = ["ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
      resources = [var.ecr_repository_arn]
    }
  }

  statement {
    sid       = "RollOutLambda"
    actions   = ["lambda:UpdateFunctionCode", "lambda:PublishVersion", "lambda:UpdateAlias", "lambda:GetAlias", "lambda:GetFunction", "lambda:GetFunctionConfiguration"]
    resources = [var.function_arn, "${var.function_arn}:*"]
  }

  statement {
    sid       = "ReadMigrationUrl"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_path_prefix}/DATABASE_URL_DIRECT"]
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy" "this" {
  name   = "deploy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
