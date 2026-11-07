# Cost model (estimates: verify against your own bill after the first season month)

| Piece | Pricing basis | Expected during a season month |
|---|---|---|
| Lambda | Always-free 1M requests + 400k GB-s per month (not account-age dependent) | $0 |
| API Gateway HTTP API | about $1 per million requests; **not** free for accounts created after 15 Jul 2025 | cents (a season is a few hundred thousand requests) |
| ECR | $0.10/GB-month; lifecycle keeps the last 10 images | cents |
| S3 (state + archives) | pennies per GB-month, archives are tiny | cents |
| CloudWatch Logs | $0.50/GB ingested; 14-day retention; no IPs/PII logged | cents |
| SSM Parameter Store | Standard SecureString is free | $0 |
| SNS email alarms, AWS Budgets | free at this scale | $0 |
| Neon Free | 100 CU-hours + 0.5 GB per project, scale-to-zero after 5 min, 6 h restore window | $0 (fails closed when CU-hours run out: watch it in season; Launch is pay-as-you-go) |
| Upstash Free | 500K commands/month, one free database per account | $0 (a dashboard poll is exactly 1 command: ~150K per season for 3 admins) |
| Gemini | free tier; content may be used to improve Google products => only PII-free aggregates are sent | $0 |
| **Total** | | **roughly $1-3 per season month, about $0 off-season** |

## Guardrails (defence in depth)
1. API Gateway throttling (default + much stricter on login and the public tracking route): real-time cap on request volume.
2. Lambda `reserved_concurrency` (needs a raised account quota first): real-time cap on parallelism.
3. Alarm on invocations/day, errors, throttles, API 5xx -> email.
4. AWS Budgets at 50/80/100% actual + 100% forecast -> email (lags by hours: it is a smoke detector, not a fuse).
5. Nothing that bills by the hour exists: no VPC/NAT (~$33/month), no provisioned concurrency, no WAF, no X-Ray, no Secrets Manager, no load balancer.

## Things that would silently add cost (do not add without a decision)
NAT gateway or VPC endpoints, provisioned concurrency, Secrets Manager, Route 53 hosted zone ($0.50/month; use your registrar's DNS),
log groups without retention, SSE/streaming Lambdas (each open connection pins a Lambda: ~$10+/season for 3 admins), always-on WhatsApp gateways.
**AWS account plan:** accounts created after 15 Jul 2025 start on a credit-based Free plan that closes the account when the
6 months or credits run out. Switch to the Paid plan: always-free items stay free.
