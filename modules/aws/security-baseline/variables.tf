variable "ebs_kms_key_arn" {
  type        = string
  default     = null
  description = "Customer-managed key for default EBS encryption. Null = AWS-managed key."
}

variable "guardduty_s3_protection" {
  type    = bool
  default = true
}

variable "security_hub" {
  type        = bool
  default     = false
  description = "Enable Security Hub + CIS v3.0 (paid). Off in labs; Cloud Copilot covers detection."
}

variable "tags" {
  type    = map(string)
  default = {}
}
