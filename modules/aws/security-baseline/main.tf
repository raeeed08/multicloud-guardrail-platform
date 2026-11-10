# Account-wide safety nets, applied once per account and region. Each line closes a whole class of mistakes,
# including in resources created later by people who never read this repository.

# STO-001 safety net: no bucket in the account can become public, whatever its own settings.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ENC-001 safety net: every new EBS volume and snapshot copy is encrypted.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "this" {
  count   = var.ebs_kms_key_arn == null ? 0 : 1
  key_arn = var.ebs_kms_key_arn
}

# No EBS snapshot can be shared publicly (Cloud Copilot EBS-003).
resource "aws_ebs_snapshot_block_public_access" "this" {
  state = "block-all-sharing"
}

# CMP-001 safety net: new instances default to IMDSv2 unless explicitly overridden.
resource "aws_ec2_instance_metadata_defaults" "this" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 2 # 2 lets containers on the instance reach IMDS
}

# CIS AWS 1.8-1.9
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}

# Finds resources shared with outside accounts (buckets, roles, keys...). Free for external access.
resource "aws_accessanalyzer_analyzer" "this" {
  analyzer_name = "account-external-access"
  type          = "ACCOUNT"
  tags          = var.tags
}

# Threat detection (Cloud Copilot GD-001). Priced per analysed event; the 30-day trial is free.
resource "aws_guardduty_detector" "this" {
  #checkov:skip=CKV2_AWS_3:Organisation-wide delegation is configured from the management account, not per workload account.
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags                         = var.tags
}

resource "aws_guardduty_detector_feature" "s3" {
  count       = var.guardduty_s3_protection ? 1 : 0
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# Optional: Security Hub with the CIS AWS Foundations Benchmark v3.0 (billed per check).
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_securityhub_account" "this" {
  count                    = var.security_hub ? 1 : 0
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.security_hub ? 1 : 0
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.region}::standards/cis-aws-foundations-benchmark/v/3.0.0"
  depends_on    = [aws_securityhub_account.this]
}
