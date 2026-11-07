env               = "production"
github_app_repo   = "YOUR-GITHUB-USER/lontong-stack" # TODO: replace
alarm_email       = "you@example.com"                # TODO: replace
tracking_base_url = "https://lontongbandung.online"  # TODO: confirm

# Production: cap parallelism and rate. Reserved concurrency needs a raised Lambda account quota
# (Service Quotas -> Lambda -> Concurrent executions); leave at -1 until then.
lambda_reserved_concurrency = -1
throttle_rate               = 50
throttle_burst              = 100
