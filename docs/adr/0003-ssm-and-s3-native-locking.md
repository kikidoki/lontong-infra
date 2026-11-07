# 0003: SSM Parameter Store for secrets, S3 native state locking
Standard SecureString parameters are free (Secrets Manager is $0.40/secret/month). Terraform seeds each parameter with `__UNSET__`
and ignores the value afterwards, so secrets never enter Terraform state; the app refuses to treat the placeholder as a secret.
Terraform >= 1.10 locks state with a lock file in S3 (`use_lockfile = true`): no DynamoDB table to pay for.
