# Review rules for infrastructure PRs (AI reviewer and humans)

This stack targets ALMOST-ZERO COST. Flag as **blocking**: NAT gateways, Lambda attached to a VPC, provisioned concurrency,
WAF, X-Ray, Secrets Manager, load balancers, RDS/Aurora/OpenSearch, any new always-on resource, CloudWatch log groups
without `retention_in_days`, S3 buckets without public-access-block + encryption, IAM `*` actions on `*` resources outside the
bootstrap apply roles, secrets or account IDs committed to git, throttles/limits removed from the API.
Flag as **important**: changes that would recreate the Lambda/alias/ECR (data loss, downtime), missing `lifecycle` guards, drift risks.
Summarise the plan's cost impact in one line.
