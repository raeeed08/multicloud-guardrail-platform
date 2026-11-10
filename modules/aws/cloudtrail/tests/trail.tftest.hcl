mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
  # The key and bucket modules render policy documents; the mock must return valid JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{}"
      minified_json = "{}"
    }
  }
}

variables {
  bucket_name = "lz-test-cloudtrail-111122223333"
}

run "complete_and_tamper_evident" {
  command = plan

  assert {
    condition     = aws_cloudtrail.this.is_multi_region_trail && aws_cloudtrail.this.include_global_service_events
    error_message = "LOG-001: every region and global services."
  }

  assert {
    condition     = aws_cloudtrail.this.enable_log_file_validation
    error_message = "LOG-001: log file validation (tamper evidence)."
  }

  assert {
    condition     = aws_cloudwatch_log_group.trail.retention_in_days >= 90
    error_message = "LOG-001: retain at least 90 days."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.guardrail_tampering.threshold == 1
    error_message = "A single tampering event must alarm."
  }
}

run "rejects_short_retention" {
  command = plan

  variables {
    cloudwatch_retention_days = 30
  }

  expect_failures = [var.cloudwatch_retention_days]
}
