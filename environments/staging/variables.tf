variable "env" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "image_uri" {
  type        = string
  default     = "unused-after-first-apply"
  description = "Needed only for the FIRST apply (see README, 'First deploy'); CI manages the running image afterwards."
}

variable "ecr_repository_name" {
  type    = string
  default = "lontong-api"
}

variable "github_app_repo" {
  type        = string
  description = "owner/name of the lontong-stack repository (trusted to deploy)"
}

variable "alarm_email" {
  type = string
}

variable "tracking_base_url" {
  type        = string
  description = "Public frontend URL used in customer tracking links, e.g. https://lontongbandung.online"
}

variable "cors_origins" {
  type    = list(string)
  default = []
}

variable "ai_enabled" {
  type    = bool
  default = false
}

variable "lambda_memory_mb" {
  type    = number
  default = 512
}

variable "lambda_reserved_concurrency" {
  type    = number
  default = -1
}

variable "throttle_rate" {
  type    = number
  default = 50
}

variable "throttle_burst" {
  type    = number
  default = 100
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "custom_domain" {
  type    = string
  default = null
}

variable "certificate_arn" {
  type    = string
  default = null
}
