# One container-image Lambda behind an alias called "live".
# Terraform owns the SHAPE (role, memory, timeout, env, logs, alias). The app repo's CI owns WHICH IMAGE runs
# (update-function-code + alias flip), hence ignore_changes below. Rollback = point the alias at the previous version.
# No VPC on purpose: Neon, Upstash and Gemini are reached over TLS, and a NAT gateway alone costs about $33/month.

variable "name" {
  type = string
}

variable "image_uri" {
  type        = string
  description = "Only used for the very first creation; CI manages the image afterwards."
}

variable "memory_mb" {
  type    = number
  default = 512
}

variable "timeout_seconds" {
  type    = number
  default = 29 # API Gateway HTTP API cuts requests at 30 s
}

variable "architecture" {
  type    = string
  default = "x86_64"
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "ssm_path_prefix" {
  type = string
}

variable "archive_bucket_arn" {
  type    = string
  default = null
}

variable "reserved_concurrency" {
  type        = number
  default     = -1
  description = "Hard cap on parallel executions (cost + abuse guard). -1 = no reservation. NOTE: new AWS accounts can have a very low account quota; raise it in Service Quotas before reserving."
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alias_name" {
  type    = string
  default = "live"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ReadOwnParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_path_prefix}*"]
  }

  dynamic "statement" {
    for_each = var.archive_bucket_arn == null ? [] : [1]
    content {
      sid       = "ArchiveBucketObjects"
      actions   = ["s3:PutObject", "s3:GetObject"]
      resources = ["${var.archive_bucket_arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = var.archive_bucket_arn == null ? [] : [1]
    content {
      sid       = "ArchiveBucketList"
      actions   = ["s3:ListBucket"]
      resources = [var.archive_bucket_arn]
    }
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "app"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days # log groups never expire by default: always set retention
}

resource "aws_lambda_function" "this" {
  function_name                  = var.name
  role                           = aws_iam_role.this.arn
  package_type                   = "Image"
  image_uri                      = var.image_uri
  architectures                  = [var.architecture]
  memory_size                    = var.memory_mb
  timeout                        = var.timeout_seconds
  publish                        = true
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = var.environment
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_iam_role_policy_attachment.logs]

  lifecycle {
    ignore_changes = [image_uri]
  }
}

resource "aws_lambda_alias" "live" {
  name             = var.alias_name
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version

  lifecycle {
    ignore_changes = [function_version]
  }
}

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "alias_name" {
  value = aws_lambda_alias.live.name
}

output "alias_invoke_arn" {
  value = aws_lambda_alias.live.invoke_arn
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
