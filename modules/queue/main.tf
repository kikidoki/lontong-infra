# TODO(whatsapp-cloud-api): NOT used yet (the environments reference it only in a commented block).
# SQS queue + dead-letter queue for the automatic-notification worker. SQS's first 1M requests/month are free.

variable "name" {
  type = string
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 120 # must exceed the worker timeout
}

variable "max_receive_count" {
  type    = number
  default = 5
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "main" {
  name                       = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

output "queue_url" {
  value = aws_sqs_queue.main.url
}

output "queue_arn" {
  value = aws_sqs_queue.main.arn
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}
