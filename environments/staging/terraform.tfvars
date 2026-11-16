env               = "staging"
github_app_repo   = "YOUR-GITHUB-USER/lontong-stack"        # TODO: replace
alarm_email       = "you@example.com"                       # TODO: replace
tracking_base_url = "https://staging.lontongbandung.online" # TODO: your staging frontend URL

# Staging is allowed to be small and cheap.
throttle_rate  = 20
throttle_burst = 40

# API behind Cloudflare. The default execute-api URL is disabled, so both values are required.
custom_domain_name  = "api-staging.lontongbandung.online"                                     # TODO: confirm
acm_certificate_arn = "arn:aws:acm:ap-southeast-1:ACCOUNT_ID:certificate/REPLACE-ME"   # TODO: ACM cert in ap-southeast-1
