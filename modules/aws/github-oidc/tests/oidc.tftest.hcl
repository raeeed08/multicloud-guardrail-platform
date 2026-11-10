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
  subjects    = ["repo:raeeed08/multicloud-guardrail-platform:environment:dev"]
  policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
}

run "short_sessions_and_provider" {
  command = plan

  assert {
    condition     = aws_iam_role.github.max_session_duration == 3600
    error_message = "CI sessions last at most one hour."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "The GitHub OIDC provider is created by default."
  }
}

run "rejects_wildcard_subject" {
  command = plan

  variables {
    subjects = ["repo:raeeed08/*"]
  }

  expect_failures = [var.subjects]
}

run "rejects_administrator_access" {
  command = plan

  variables {
    policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  }

  expect_failures = [var.policy_arns]
}
