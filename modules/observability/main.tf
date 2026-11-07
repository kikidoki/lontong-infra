variable "name" {
  type = string
}

variable "alarm_email" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "api_id" {
  type = string
}

variable "daily_invocation_alarm" {
  type        = number
  default     = 50000
  description = "Cost circuit-breaker signal: far more invocations/day than a season ever needs."
}

resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email" # AWS emails a confirmation link: click it once
  endpoint  = var.alarm_email
}

locals {
  alarms = {
    lambda-errors = {
      namespace  = "AWS/Lambda"
      metric     = "Errors"
      dimensions = { FunctionName = var.lambda_function_name }
      stat       = "Sum"
      period     = 300
      threshold  = 1
    }
    lambda-throttles = {
      namespace  = "AWS/Lambda"
      metric     = "Throttles"
      dimensions = { FunctionName = var.lambda_function_name }
      stat       = "Sum"
      period     = 300
      threshold  = 1
    }
    api-5xx = {
      namespace  = "AWS/ApiGateway"
      metric     = "5xx"
      dimensions = { ApiId = var.api_id }
      stat       = "Sum"
      period     = 300
      threshold  = 3
    }
    lambda-invocations-per-day = {
      namespace  = "AWS/Lambda"
      metric     = "Invocations"
      dimensions = { FunctionName = var.lambda_function_name }
      stat       = "Sum"
      period     = 86400
      threshold  = var.daily_invocation_alarm
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each            = local.alarms
  alarm_name          = "${var.name}-${each.key}"
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  dimensions          = each.value.dimensions
  statistic           = each.value.stat
  period              = each.value.period
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

output "topic_arn" {
  value = aws_sns_topic.alarms.arn
}
