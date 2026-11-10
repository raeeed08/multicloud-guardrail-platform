variable "role_name" {
  type    = string
  default = "github-actions-deploy"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "The GitHub OIDC provider exists once per account; set false if another stack created it."
}

variable "subjects" {
  type        = list(string)
  description = "Exact token subjects, e.g. repo:owner/repo:environment:dev. Exact match only: no wildcards."
  validation {
    condition     = length(var.subjects) > 0 && alltrue([for s in var.subjects : startswith(s, "repo:") && !strcontains(s, "*")])
    error_message = "Subjects must start with repo: and contain no wildcard."
  }
}

variable "policy_arns" {
  type = list(string)
  validation {
    condition     = alltrue([for p in var.policy_arns : !endswith(p, ":policy/AdministratorAccess")])
    error_message = "IAM-001: the CI role never gets AdministratorAccess. Use a scoped deployment policy."
  }
}

variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Caps what the role (and any role it creates) can ever do."
}

variable "tags" {
  type    = map(string)
  default = {}
}
