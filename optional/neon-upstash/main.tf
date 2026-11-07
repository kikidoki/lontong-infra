# OPTIONAL and NOT WIRED INTO environments/*. The Neon and Upstash free plans are one click each in their consoles,
# which is the recommended path (paste the connection strings into SSM). Use this only if you want the two SaaS
# databases in code too. UNVALIDATED: written from the providers' docs without `terraform validate` access.
# Check argument/attribute names against the current provider docs before applying.
#   Neon:    https://registry.terraform.io/providers/kislerdm/neon  (community provider, sponsored by Neon)
#   Upstash: https://registry.terraform.io/providers/upstash/upstash (official)
# Free-plan facts to respect: Neon Free = 100 CU-hours + 0.5 GB per project and a 6 h restore window (one project
# per environment keeps quotas separate); Upstash Free = one free database per account (staging may need pay-as-you-go + a budget).

terraform {
  required_providers {
    neon = {
      source = "kislerdm/neon"
    }
    upstash = {
      source = "upstash/upstash"
    }
  }
}

variable "env" {
  type = string
}

variable "upstash_email" {
  type = string
}

variable "upstash_api_key" {
  type      = string
  sensitive = true
}

provider "neon" {} # NEON_API_KEY from the environment

provider "upstash" {
  email   = var.upstash_email
  api_key = var.upstash_api_key
}

resource "neon_project" "this" {
  name                      = "lontong-${var.env}"
  region_id                 = "aws-ap-southeast-1" # Singapore (Neon has no Jakarta region)
  pg_version                = 16
  history_retention_seconds = 21600 # 6 h: the maximum on the Free plan

  branch {
    name          = "main"
    database_name = "lontong"
    role_name     = "lontong_owner"
  }
}

resource "upstash_redis_database" "this" {
  database_name  = "lontong-${var.env}"
  region         = "global"
  primary_region = "ap-southeast-1"
  tls            = true
}

output "database_url_direct" {
  value     = neon_project.this.connection_uri
  sensitive = true
}

output "upstash_rest_url" {
  value = "https://${upstash_redis_database.this.endpoint}"
}

output "upstash_rest_token" {
  value     = upstash_redis_database.this.rest_token
  sensitive = true
}
# Pooled URL: take the Neon connection string from the console with "Pooled connection" enabled
# (host contains "-pooler") and store it as DATABASE_URL.
