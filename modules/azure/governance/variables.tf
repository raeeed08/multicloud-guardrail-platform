variable "subscription_id" {
  type = string
}

variable "allowed_locations" {
  type    = list(string)
  default = ["westeurope", "northeurope"]
}

variable "required_tags" {
  type    = list(string)
  default = ["owner", "environment", "project"]
}

variable "enforce" {
  type        = bool
  default     = true
  description = "false = audit mode (DoNotEnforce): report violations without blocking, useful for a rollout."
}

variable "effect" {
  type        = string
  default     = "Deny"
  description = "Effect for the storage policies: Audit while rolling out, Deny once clean."
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.effect)
    error_message = "effect is Audit, Deny or Disabled."
  }
}

variable "defender_plans" {
  type        = list(string)
  default     = []
  description = "Defender for Cloud plans to enable (Standard tier, billed), e.g. [\"VirtualMachines\", \"StorageAccounts\", \"KeyVaults\", \"Arm\"]."
}

variable "security_contact_email" {
  type    = string
  default = null
}
