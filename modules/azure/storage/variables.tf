variable "name" {
  type        = string
  description = "Globally unique storage account name (3-24 lowercase letters and digits)."
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage account names are 3-24 lowercase letters and digits."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "replication_type" {
  type        = string
  default     = "ZRS"
  description = "LRS for labs, ZRS (zone-redundant) by default, GZRS for critical data."
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "Unknown replication type."
  }
}

variable "containers" {
  type    = list(string)
  default = []
}

variable "soft_delete_days" {
  type    = number
  default = 30
  validation {
    condition     = var.soft_delete_days >= 7 && var.soft_delete_days <= 365
    error_message = "Soft delete must keep data between 7 and 365 days."
  }
}

variable "private_endpoint_subnet_id" {
  type        = string
  default     = null
  description = "Subnet for the blob private endpoint. Null = no endpoint (the account then has no network path)."
}

variable "private_dns_zone_ids" {
  type        = list(string)
  default     = []
  description = "privatelink.blob.core.windows.net zone(s) to register the endpoint in."
}

variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
