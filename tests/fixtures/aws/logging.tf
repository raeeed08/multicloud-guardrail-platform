# rules: LOG-001
# expect: LOG-001
resource "aws_cloudtrail" "weak" {
  name           = "trail"
  s3_bucket_name = "logs"
}

# safe
resource "aws_cloudtrail" "strong" {
  name                       = "org-trail"
  s3_bucket_name             = "logs"
  is_multi_region_trail      = true
  enable_log_file_validation = true
  kms_key_id                 = "arn:aws:kms:eu-west-1:111122223333:key/abc"
}

# expect: LOG-001
resource "aws_cloudwatch_log_group" "forever" {
  name = "/app/forever"
}

# expect: LOG-001
resource "aws_cloudwatch_log_group" "short" {
  name              = "/app/short"
  retention_in_days = 30
}

# safe
resource "aws_cloudwatch_log_group" "year" {
  name              = "/app/audit"
  retention_in_days = 365
}
