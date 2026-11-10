# Organisation-grade audit trail (LOG-001): multi-region, global services, log file validation,
# KMS encryption, delivered to a private S3 bucket and to CloudWatch Logs for alerting.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account    = data.aws_caller_identity.current.account_id
  trail_arn  = "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${local.account}:trail/${var.name}"
  log_prefix = "cloudtrail"
}

module "key" {
  source      = "../kms"
  alias       = "${var.name}-trail"
  description = "Encrypts CloudTrail logs and their CloudWatch log group"
  service_principals = [
    "cloudtrail.amazonaws.com",
    "logs.${data.aws_region.current.region}.amazonaws.com",
  ]
  tags = var.tags
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "CloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/${local.log_prefix}/AWSLogs/${local.account}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

module "bucket" {
  source                  = "../s3-secure-bucket"
  name                    = var.bucket_name
  kms_key_arn             = module.key.key_arn
  extra_policy_json       = data.aws_iam_policy_document.bucket.json
  noncurrent_version_days = var.retention_days
  tags                    = var.tags
}

resource "aws_cloudwatch_log_group" "trail" {
  #checkov:skip=CKV_AWS_338:CloudWatch keeps 90 days for alerting; the full history is kept in the versioned S3 bucket.
  name              = "/cloudtrail/${var.name}"
  retention_in_days = var.cloudwatch_retention_days # LOG-001
  kms_key_id        = module.key.key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "cwl_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cwl" {
  name               = "role-${var.name}-to-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.cwl_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "cwl_write" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cwl" {
  name   = "write-trail-logs"
  role   = aws_iam_role.cwl.id
  policy = data.aws_iam_policy_document.cwl_write.json
}

resource "aws_cloudtrail" "this" {
  #checkov:skip=CKV_AWS_252:Alerting uses the CloudWatch tampering alarm, not per-file SNS notifications.
  name                          = var.name
  s3_bucket_name                = module.bucket.id
  s3_key_prefix                 = local.log_prefix
  is_multi_region_trail         = true # LOG-001
  include_global_service_events = true
  enable_log_file_validation    = true # LOG-001: tamper evidence
  kms_key_id                    = module.key.key_arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cwl.arn
  tags                          = var.tags

  dynamic "event_selector" {
    for_each = var.s3_data_events ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = true
      data_resource {
        type   = "AWS::S3::Object"
        values = ["arn:${data.aws_partition.current.partition}:s3"]
      }
    }
  }

  depends_on = [module.bucket]
}

# CIS AWS 4.x: alarm on the API calls that disable the guardrails themselves.
resource "aws_cloudwatch_log_metric_filter" "guardrail_tampering" {
  name           = "${var.name}-guardrail-tampering"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = "{ ($.eventName = StopLogging) || ($.eventName = DeleteTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteDetector) || ($.eventName = PutBucketPublicAccessBlock) || ($.eventName = DeleteAccountPublicAccessBlock) || ($.eventName = AuthorizeSecurityGroupIngress) }"

  metric_transformation {
    name      = "GuardrailTampering"
    namespace = "LandingZone/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "guardrail_tampering" {
  alarm_name          = "${var.name}-guardrail-tampering"
  alarm_description   = "Someone changed logging, detection or network exposure."
  namespace           = "LandingZone/Security"
  metric_name         = aws_cloudwatch_log_metric_filter.guardrail_tampering.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  tags                = var.tags
}
