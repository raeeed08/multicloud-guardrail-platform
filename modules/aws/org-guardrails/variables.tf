variable "target_ids" {
  type        = list(string)
  description = "OU or account IDs to attach the SCPs to (never the root first: test on a sandbox OU)."
}

variable "allowed_regions" {
  type    = list(string)
  default = ["eu-west-1", "eu-west-3", "eu-central-1"]
}

variable "exempt_role_arns" {
  type        = list(string)
  default     = []
  description = "Break-glass / platform roles that may still change guardrails, e.g. arn:aws:iam::*:role/lz-break-glass."
}

variable "tags" {
  type    = map(string)
  default = {}
}
