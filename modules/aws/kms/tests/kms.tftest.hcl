mock_provider "aws" {
  # Policy documents must render as valid JSON for resources that validate it.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{}"
      minified_json = "{}"
    }
  }
}

run "rotates" {
  command = plan

  variables {
    alias = "lz-test"
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation
    error_message = "ENC-002: rotation must be enabled."
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Deleting a key must keep the maximum 30-day safety window."
  }

  assert {
    condition     = aws_kms_alias.this.name == "alias/lz-test"
    error_message = "Alias must be prefixed with alias/."
  }
}

run "rejects_short_rotation" {
  command = plan

  variables {
    alias         = "lz-test"
    rotation_days = 30
  }

  expect_failures = [var.rotation_days]
}
