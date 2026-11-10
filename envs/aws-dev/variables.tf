variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "raed"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "security_hub" {
  type    = bool
  default = false
}

variable "github_repository" {
  type    = string
  default = "raeeed08/multicloud-guardrail-platform"
}

variable "deploy_policy_arns" {
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  description = "What the CI role may do. PowerUserAccess has no IAM rights; production uses a custom scoped policy."
}
