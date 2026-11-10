output "role_arn" {
  description = "Use in aws-actions/configure-aws-credentials (role-to-assume). Not a secret."
  value       = aws_iam_role.github.arn
}
