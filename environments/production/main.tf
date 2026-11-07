locals {
  name       = "lontong-${var.env}"
  ssm_prefix = "/lontong/${var.env}"
}

data "aws_caller_identity" "current" {}

# Created once by bootstrap/ and shared by every environment ("build once, promote the same digest").
data "aws_ecr_repository" "api" {
  name = var.ecr_repository_name
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Parameter Store placeholders. Set real values with `aws ssm put-parameter --overwrite` (README, "Secrets").
module "secrets" {
  source = "../../modules/secrets"
  prefix = local.ssm_prefix
  names = [
    "DATABASE_URL",        # Neon POOLED connection string (runtime)
    "DATABASE_URL_DIRECT", # Neon DIRECT connection string (migrations, CI)
    "JWT_SECRET",
    "UPSTASH_REDIS_REST_URL",
    "UPSTASH_REDIS_REST_TOKEN",
    "GEMINI_API_KEY",
  ]
}

module "archive_bucket" {
  source = "../../modules/archive_bucket"
  name   = "${local.name}-archives-${data.aws_caller_identity.current.account_id}"
}

module "api_lambda" {
  source               = "../../modules/lambda_container"
  name                 = "${local.name}-api"
  image_uri            = var.image_uri
  memory_mb            = var.lambda_memory_mb
  reserved_concurrency = var.lambda_reserved_concurrency
  log_retention_days   = var.log_retention_days
  ssm_path_prefix      = local.ssm_prefix
  archive_bucket_arn   = module.archive_bucket.arn
  environment = {
    ENV               = var.env
    SSM_PATH_PREFIX   = local.ssm_prefix
    ARCHIVE_BUCKET    = module.archive_bucket.name
    TRACKING_BASE_URL = var.tracking_base_url
    CORS_ORIGINS      = jsonencode(var.cors_origins)
    COOKIE_SECURE     = "true"
    AI_ENABLED        = tostring(var.ai_enabled)
  }
}

module "http_api" {
  source                  = "../../modules/http_api"
  name                    = "${local.name}-api"
  lambda_alias_invoke_arn = module.api_lambda.alias_invoke_arn
  lambda_function_name    = module.api_lambda.function_name
  lambda_alias_name       = module.api_lambda.alias_name
  cors_origins            = var.cors_origins
  throttle_rate           = var.throttle_rate
  throttle_burst          = var.throttle_burst
  log_retention_days      = var.log_retention_days
  custom_domain           = var.custom_domain
  certificate_arn         = var.certificate_arn
}

module "observability" {
  source               = "../../modules/observability"
  name                 = local.name
  alarm_email          = var.alarm_email
  lambda_function_name = module.api_lambda.function_name
  api_id               = module.http_api.api_id
}

module "deploy_role" {
  source             = "../../modules/deploy_role"
  name               = "${local.name}-app-deploy"
  github_repo        = var.github_app_repo
  environment        = var.env
  oidc_provider_arn  = data.aws_iam_openid_connect_provider.github.arn
  ecr_repository_arn = data.aws_ecr_repository.api.arn
  function_arn       = module.api_lambda.function_arn
  ssm_path_prefix    = local.ssm_prefix
  allow_image_push   = var.env != "production"
}

# --------------------------------------------------------------------------------------------------------------
# TODO(whatsapp-cloud-api): automatic notifications are NOT enabled (v1 uses wa.me links).
# When you build them (apps/api/docs/TODO_WHATSAPP_CLOUD_API.md), uncomment this and add a worker function
# (same image, handler lontong.lambda_worker.handler) with an SQS event source mapping:
#
# module "notification_queue" {
#   source = "../../modules/queue"
#   name   = "${local.name}-notifications"
# }
# Also add to the Lambda role: sqs:SendMessage on the queue (api) and sqs:ReceiveMessage/DeleteMessage (worker),
# SSM params WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID / WHATSAPP_APP_SECRET, and a DLQ-depth alarm.
# --------------------------------------------------------------------------------------------------------------
