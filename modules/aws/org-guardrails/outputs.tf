output "policy_ids" {
  value = { for k, p in aws_organizations_policy.this : k => p.id }
}

output "policy_sizes" {
  description = "Characters per SCP (AWS limit: 5120)."
  value       = { for k, p in local.policies : k => length(p.json) }
}
