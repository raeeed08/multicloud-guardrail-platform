mock_provider "azurerm" {
  mock_data "azurerm_policy_definition" {
    defaults = {
      id = "/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "guardrails_assigned_and_enforced" {
  command = plan

  assert {
    condition     = length(azurerm_subscription_policy_assignment.require_tag) == 3
    error_message = "TAG-001: one assignment per mandatory tag."
  }

  assert {
    condition     = azurerm_subscription_policy_assignment.allowed_locations.enforce
    error_message = "GOV-001 must be enforced by default."
  }

  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.storage_no_public.parameters).effect.value == "Deny"
    error_message = "STO-001 must deny by default."
  }

  assert {
    condition     = length(azurerm_security_center_subscription_pricing.plan) == 0
    error_message = "Paid Defender plans are opt-in."
  }
}

run "audit_mode_rollout" {
  command = plan

  variables {
    enforce = false
    effect  = "Audit"
  }

  assert {
    condition     = azurerm_subscription_policy_assignment.allowed_locations.enforce == false
    error_message = "Audit mode must not enforce."
  }
}

run "rejects_unknown_effect" {
  command = plan

  variables {
    effect = "Block"
  }

  expect_failures = [var.effect]
}
