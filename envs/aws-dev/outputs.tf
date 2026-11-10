output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "data_bucket" {
  value = module.data_bucket.id
}

output "cloudtrail_bucket" {
  value = module.trail.bucket
}

output "github_role_arn" {
  description = "AWS_ROLE_ARN for the GitHub environment."
  value       = module.github_oidc.role_arn
}
