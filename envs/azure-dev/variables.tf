variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (from tfvars or TF_VAR_subscription_id, never committed)."
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "allowed_locations" {
  type    = list(string)
  default = ["westeurope", "northeurope"]
}

variable "name_prefix" {
  type    = string
  default = "lz-dev"
}

variable "github_repository" {
  type        = string
  default     = "raeeed08/multicloud-guardrail-platform"
  description = "owner/repo allowed to deploy through OIDC."
}

variable "security_email" {
  type        = string
  default     = null
  description = "Receives Defender and activity log alerts."
}

variable "enforce_policies" {
  type    = bool
  default = true
}

variable "defender_plans" {
  type    = list(string)
  default = []
}

variable "storage_replication" {
  type    = string
  default = "LRS" # lab cost; production uses ZRS or GZRS
}

variable "tags" {
  type = map(string)
  default = {
    owner   = "raed"
    project = "landing-zone"
  }
}
