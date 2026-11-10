variable "name" {
  type        = string
  description = "Globally unique vault name (3-24 characters)."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name is standard or premium (HSM-backed keys)."
  }
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_ids" {
  type    = list(string)
  default = []
}

variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

variable "role_assignments" {
  type = map(object({
    role         = string
    principal_id = string
  }))
  default     = {}
  description = "Data-plane roles, e.g. { app = { role = \"Key Vault Secrets User\", principal_id = \"...\" } }."
  validation {
    condition     = alltrue([for a in values(var.role_assignments) : startswith(a.role, "Key Vault ")])
    error_message = "Only Key Vault data-plane roles may be assigned here (least privilege)."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
