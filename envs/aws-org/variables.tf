variable "owner" {
  type    = string
  default = "raed"
}

variable "target_ou_ids" {
  type        = list(string)
  description = "Start with a sandbox OU (ou-xxxx-xxxxxxxx), then workloads. Never the root first."
}

variable "allowed_regions" {
  type    = list(string)
  default = ["eu-west-1", "eu-west-3", "eu-central-1"]
}

variable "exempt_role_arns" {
  type    = list(string)
  default = ["arn:aws:iam::*:role/lz-break-glass"]
}
