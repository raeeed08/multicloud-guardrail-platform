variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subjects" {
  type        = list(string)
  description = "Trusted token subjects, e.g. repo:owner/repo:environment:dev (scope trust to an environment, not a whole repo)."
  validation {
    condition     = alltrue([for s in var.subjects : startswith(s, "repo:") && !endswith(s, ":*")])
    error_message = "Subjects must start with repo: and must not end with a wildcard."
  }
}

variable "role_assignments" {
  type = map(object({
    scope = string
    role  = string
  }))
  default = {}
  validation {
    condition     = alltrue([for a in values(var.role_assignments) : !contains(["Owner", "User Access Administrator"], a.role)])
    error_message = "IAM-001: the CI identity never gets Owner or User Access Administrator."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
