mock_provider "aws" {
  # Policy documents must render as valid JSON for resources that validate it.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{}"
      minified_json = "{}"
    }
  }
}

variables {
  target_ids = ["ou-abcd-11111111", "ou-abcd-22222222"]
}

run "three_policies_attached_to_every_target" {
  command = plan

  assert {
    condition     = length(aws_organizations_policy.this) == 3
    error_message = "protect-security, data-protection and regions SCPs expected."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.this) == 6
    error_message = "Every SCP must be attached to every target."
  }

  assert {
    condition     = alltrue([for p in aws_organizations_policy.this : p.type == "SERVICE_CONTROL_POLICY"])
    error_message = "Only service control policies."
  }
}
