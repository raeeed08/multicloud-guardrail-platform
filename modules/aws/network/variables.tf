variable "name_prefix" {
  type = string
}

variable "cidr" {
  type    = string
  default = "10.20.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR."
  }
}

variable "az_count" {
  type    = number
  default = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "Use 2 to 4 availability zones."
  }
}

variable "enable_nat" {
  type        = bool
  default     = false
  description = "One NAT gateway (~32 USD/month + data). Off for labs: private subnets reach S3 through the endpoint."
}

variable "flow_log_retention_days" {
  type    = number
  default = 90
  validation {
    condition     = var.flow_log_retention_days >= 90
    error_message = "LOG-001: keep flow logs at least 90 days."
  }
}

variable "kms_key_arn" {
  type    = string
  default = null
}
