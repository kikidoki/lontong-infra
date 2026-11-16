# API Gateway HTTP API (about $1 per million requests) in front of the Lambda alias.
# Throttling is the real-time cost/abuse guard: a default limit plus much stricter limits on login and the public tracking page.

variable "name" {
  type = string
}

variable "lambda_alias_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "lambda_alias_name" {
  type = string
}

variable "cors_origins" {
  type        = list(string)
  default     = []
  description = "Leave empty when the frontend proxies /api through the same origin (Vercel rewrites)."
}

variable "throttle_rate" {
  type    = number
  default = 50
}

variable "throttle_burst" {
  type    = number
  default = 100
}

variable "login_rate" {
  type    = number
  default = 2
}

variable "login_burst" {
  type    = number
  default = 5
}

variable "track_rate" {
  type    = number
  default = 20
}

variable "track_burst" {
  type    = number
  default = 40
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "custom_domain_name" {
  type        = string
  description = "e.g. api.lontongbandung.online. Required: the default execute-api URL is disabled, so this is the only way in."
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate for custom_domain_name, in the SAME region as the API (ap-southeast-1)."
}

locals {
  login_route = "POST /api/v1/auth/login"
  track_route = "GET /api/v1/public/track/{token}"
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"

  # Bots cannot call https://<id>.execute-api.<region>.amazonaws.com directly: the only way in is the custom domain
  # (behind Cloudflare, which adds the secret header the API checks).
  disable_execute_api_endpoint = true

  dynamic "cors_configuration" {
    for_each = length(var.cors_origins) > 0 ? [1] : []
    content {
      allow_origins     = var.cors_origins
      allow_methods     = ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
      allow_headers     = ["authorization", "content-type", "if-none-match"]
      expose_headers    = ["etag"]
      allow_credentials = true
      max_age           = 600
    }
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_alias_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = local.login_route
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "track" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = local.track_route
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttle_rate
    throttling_burst_limit = var.throttle_burst
  }

  route_settings {
    route_key              = local.login_route
    throttling_rate_limit  = var.login_rate
    throttling_burst_limit = var.login_burst
  }

  route_settings {
    route_key              = local.track_route
    throttling_rate_limit  = var.track_rate
    throttling_burst_limit = var.track_burst
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    # No IPs or headers on purpose: nothing personal in the logs.
    format = jsonencode({
      requestId        = "$context.requestId"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      latencyMs        = "$context.responseLatency"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  depends_on = [aws_apigatewayv2_route.default, aws_apigatewayv2_route.login, aws_apigatewayv2_route.track]
}

resource "aws_lambda_permission" "invoke" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  qualifier     = var.lambda_alias_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_apigatewayv2_domain_name" "this" {
  domain_name = var.custom_domain_name
  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this.id
  stage       = aws_apigatewayv2_stage.default.id
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "target_domain_name" {
  description = "Point your Cloudflare DNS CNAME for custom_domain_name at this (proxied)."
  value       = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].target_domain_name
}

output "hosted_zone_id" {
  description = "Route 53 alias zone id of the regional endpoint (not needed for Cloudflare CNAMEs; exposed for completeness)."
  value       = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].hosted_zone_id
}
