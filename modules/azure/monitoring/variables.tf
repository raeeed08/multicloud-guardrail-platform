variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "retention_days" {
  type    = number
  default = 90
  validation {
    condition     = var.retention_days >= 90 && var.retention_days <= 730
    error_message = "Keep security logs at least 90 days (LOG-001) and at most 730 in the workspace."
  }
}

variable "daily_quota_gb" {
  type        = number
  default     = 5
  description = "Daily ingestion cap in GB to avoid surprise bills; -1 removes the cap (production)."
}

variable "alert_email" {
  type        = string
  default     = null
  description = "Where security alerts go. Null = no action group and no activity log alerts."
}

variable "tags" {
  type    = map(string)
  default = {}
}
