output "api_url" {
  description = "Base URL of the API (set as the API_URL variable in the app repo's GitHub environment)"
  value       = module.http_api.api_url
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

output "custom_domain_target" {
  value = module.http_api.custom_domain_target
}
