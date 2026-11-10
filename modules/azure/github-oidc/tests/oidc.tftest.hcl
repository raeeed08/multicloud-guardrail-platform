mock_provider "azurerm" {}

variables {
  name_prefix         = "lz-test"
  location            = "westeurope"
  resource_group_name = "rg-test"
  subjects            = ["repo:raeeed08/multicloud-guardrail-platform:environment:dev"]
  role_assignments    = { deploy = { scope = "/subscriptions/0/resourceGroups/rg-test", role = "Contributor" } }
}

run "federated_to_github" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.github["repo:raeeed08/multicloud-guardrail-platform:environment:dev"].issuer == "https://token.actions.githubusercontent.com"
    error_message = "Only GitHub's OIDC issuer is trusted."
  }
}

run "rejects_owner" {
  command = plan

  variables {
    role_assignments = { admin = { scope = "/subscriptions/0", role = "Owner" } }
  }

  expect_failures = [var.role_assignments]
}

run "rejects_wildcard_subject" {
  command = plan

  variables {
    subjects = ["repo:raeeed08/multicloud-guardrail-platform:*"]
  }

  expect_failures = [var.subjects]
}
