mock_provider "aws" {
  # Policy documents must render as valid JSON for resources that validate it.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{}"
      minified_json = "{}"
    }
  }
}

run "safety_nets_on" {
  command = plan

  assert {
    condition     = aws_ebs_encryption_by_default.this.enabled
    error_message = "ENC-001: EBS encryption by default."
  }

  assert {
    condition     = aws_ec2_instance_metadata_defaults.this.http_tokens == "required"
    error_message = "CMP-001: IMDSv2 by default."
  }

  assert {
    condition     = aws_ebs_snapshot_block_public_access.this.state == "block-all-sharing"
    error_message = "Snapshots can never be public."
  }

  assert {
    condition     = aws_iam_account_password_policy.this.minimum_password_length >= 14
    error_message = "CIS 1.8: 14+ character passwords."
  }

  assert {
    condition     = aws_guardduty_detector.this.enable
    error_message = "GuardDuty must be on."
  }

  assert {
    condition     = length(aws_securityhub_account.this) == 0
    error_message = "Security Hub is opt-in (cost)."
  }
}
