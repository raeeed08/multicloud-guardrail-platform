variable "name" {
  type    = string
  default = "org-trail"
}

variable "bucket_name" {
  type = string
}

variable "retention_days" {
  type        = number
  default     = 365
  description = "How long old object versions stay in the log bucket."
}

variable "cloudwatch_retention_days" {
  type    = number
  default = 90
  validation {
    condition     = var.cloudwatch_retention_days >= 90
    error_message = "LOG-001: at least 90 days."
  }
}

variable "s3_data_events" {
  type        = bool
  default     = false
  description = "Record S3 object-level access (billed per event)."
}

variable "alarm_topic_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
