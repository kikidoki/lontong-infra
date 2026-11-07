# Run ONCE per AWS account, with local state (then move the state into the bucket it creates; see README).
# Creates: Terraform state bucket, GitHub OIDC provider + CI roles (no long-lived AWS keys), the shared ECR repository
# and the account-wide monthly cost budget.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "lontong"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-1" # Singapore: the nearest region that Neon also offers
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique, e.g. lontong-tfstate-<aws-account-id>"
}

variable "infra_repo" {
  type        = string
  description = "GitHub repo of this project, as owner/name"
}

variable "ecr_repository_name" {
  type    = string
  default = "lontong-api"
}

variable "budget_limit_usd" {
  type    = number
  default = 5
}

variable "budget_emails" {
  type = list(string)
}

# ------------------------------------------------------------------ state bucket (S3 native locking: no DynamoDB)
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}

# ------------------------------------------------------------------ GitHub OIDC (one per account)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # AWS validates GitHub via trusted CAs; kept for older provider versions
}

locals {
  oidc_arn = aws_iam_openid_connect_provider.github.arn
  sub_key  = "token.actions.githubusercontent.com:sub"
  aud_key  = "token.actions.githubusercontent.com:aud"
}

data "aws_iam_policy_document" "trust" {
  for_each = {
    plan             = "repo:${var.infra_repo}:pull_request"
    apply-staging    = "repo:${var.infra_repo}:environment:staging"
    apply-production = "repo:${var.infra_repo}:environment:production"
  }
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = local.aud_key
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = local.sub_key
      values   = [each.value]
    }
  }
}

resource "aws_iam_role" "terraform" {
  for_each           = data.aws_iam_policy_document.trust
  name               = "lontong-tf-${each.key}"
  assume_role_policy = each.value.json
}

# plan: read-only (PR plans run with -lock=false). apply: administrator, but ONLY assumable from the matching
# GitHub environment (production needs your approval). TODO: tighten the apply roles once the stack settles.
resource "aws_iam_role_policy_attachment" "terraform" {
  for_each   = aws_iam_role.terraform
  role       = each.value.name
  policy_arn = each.key == "plan" ? "arn:aws:iam::aws:policy/ReadOnlyAccess" : "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------ shared ECR repository ("build once, promote")
module "ecr" {
  source = "../modules/ecr"
  name   = var.ecr_repository_name
}

# ------------------------------------------------------------------ account-wide cost alarm
module "budget" {
  source    = "../modules/budgets"
  name      = "lontong-monthly"
  limit_usd = var.budget_limit_usd
  emails    = var.budget_emails
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "oidc_provider_arn" {
  value = local.oidc_arn
}

output "terraform_role_arns" {
  value = { for k, r in aws_iam_role.terraform : k => r.arn }
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
