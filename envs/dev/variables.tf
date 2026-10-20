variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (supplied via tfvars or env var, never committed)."
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "name_prefix" {
  type    = string
  default = "platform-dev"
}

variable "tags" {
  type = map(string)
  default = {
    project = "platform"
    env     = "dev"
    owner   = "raed"
  }
}
