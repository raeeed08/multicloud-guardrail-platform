variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.name))
    error_message = "Invalid S3 bucket name."
  }
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Customer-managed key. Null = SSE-S3 (AES256)."
}

variable "noncurrent_version_days" {
  type    = number
  default = 90
}

variable "access_log_bucket" {
  type    = string
  default = null
}

variable "extra_policy_json" {
  type        = string
  default     = null
  description = "Additional bucket policy statements (merged), e.g. CloudTrail write access."
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
