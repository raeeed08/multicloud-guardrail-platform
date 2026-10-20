variable "name_prefix" {
  type        = string
  description = "Short prefix used in resource names, e.g. platform-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that holds the network."
}

variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "app_subnet_cidr" {
  type    = string
  default = "10.10.0.0/23"
}

variable "pe_subnet_cidr" {
  type    = string
  default = "10.10.2.0/27"
}

variable "mgmt_subnet_cidr" {
  type    = string
  default = "10.10.2.32/27"
}

variable "tags" {
  type    = map(string)
  default = {}
}
