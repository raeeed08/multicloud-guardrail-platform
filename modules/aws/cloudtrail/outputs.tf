output "trail_arn" {
  value = aws_cloudtrail.this.arn
}

output "bucket" {
  value = module.bucket.id
}

output "kms_key_arn" {
  value = module.key.key_arn
}

output "log_group" {
  value = aws_cloudwatch_log_group.trail.name
}
