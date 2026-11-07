# The bucket name is supplied at init time (-backend-config="bucket=...") by scripts/tf.sh and CI,
# so no account-specific value lives in git. One state file per environment: that is the blast-radius boundary.
terraform {
  backend "s3" {
    key          = "staging/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.10): no DynamoDB table to pay for or maintain
  }
}
