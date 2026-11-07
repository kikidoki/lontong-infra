# Parameter Store SecureString (Standard tier) is free; Secrets Manager costs $0.40/secret/month.
# Terraform creates the parameters with a placeholder and NEVER manages the value afterwards:
#   aws ssm put-parameter --name /lontong/<env>/JWT_SECRET --type SecureString --overwrite --value '...'
# The app ignores PLACEHOLDER values (see lontong/bootstrap.py), so an unset secret fails loudly instead of silently.

variable "prefix" {
  type = string
}

variable "names" {
  type = set(string)
}

resource "aws_ssm_parameter" "this" {
  for_each = var.names
  name     = "${var.prefix}/${each.key}"
  type     = "SecureString"
  value    = "__UNSET__"

  lifecycle {
    ignore_changes = [value]
  }
}

output "parameter_arns" {
  value = [for p in aws_ssm_parameter.this : p.arn]
}
