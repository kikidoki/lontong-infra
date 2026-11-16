env               = "production"
github_app_repo   = "YOUR-GITHUB-USER/lontong-stack" # TODO: replace
alarm_email       = "you@example.com"                # TODO: replace
tracking_base_url = "https://lontongbandung.online"  # TODO: confirm

# Production: cap parallelism and rate. Reserved concurrency needs a raised Lambda account quota
# (Service Quotas -> Lambda -> Concurrent executions); leave at -1 until then.
lambda_reserved_concurrency = -1
throttle_rate               = 50
throttle_burst              = 100

# API behind Cloudflare. The default execute-api URL is disabled, so both values are required.
custom_domain_name  = "api.lontongbandung.online"                                     # TODO: confirm
acm_certificate_arn = "arn:aws:acm:ap-southeast-1:ACCOUNT_ID:certificate/REPLACE-ME"   # TODO: ACM cert in ap-southeast-1
