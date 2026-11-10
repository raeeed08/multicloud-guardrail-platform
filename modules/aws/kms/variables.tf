variable "alias" {
  type        = string
  description = "Alias without the alias/ prefix."
}

variable "description" {
  type    = string
  default = "Customer-managed key"
}

variable "rotation_days" {
  type    = number
  default = 365
  validation {
    condition     = var.rotation_days >= 90 && var.rotation_days <= 2560
    error_message = "KMS rotation period is 90 to 2560 days."
  }
}

variable "service_principals" {
  type        = list(string)
  default     = []
  description = "AWS services allowed to use the key for this account, e.g. [\"logs.eu-west-1.amazonaws.com\"]."
}

variable "tags" {
  type    = map(string)
  default = {}
}
