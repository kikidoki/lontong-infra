output "api_url" {
  description = "Public API base URL (the default execute-api URL is disabled). Set as API_URL in the app repo's GitHub environment."
  value       = "https://${var.custom_domain_name}"
}

output "lambda_function_name" {
  value = module.api_lambda.function_name
}

output "deploy_role_arn" {
  description = "Set as AWS_DEPLOY_ROLE_ARN in the app repo's GitHub environment"
  value       = module.deploy_role.role_arn
}

output "archive_bucket" {
  value = module.archive_bucket.name
}

output "ssm_prefix" {
  value = local.ssm_prefix
}

output "target_domain_name" {
  description = "Cloudflare DNS: CNAME <custom_domain_name> -> this value, proxied (orange cloud)"
  value       = module.http_api.target_domain_name
}

output "hosted_zone_id" {
  value = module.http_api.hosted_zone_id
}
