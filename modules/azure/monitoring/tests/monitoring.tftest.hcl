mock_provider "azurerm" {}

variables {
  name_prefix         = "lz-test"
  location            = "westeurope"
  resource_group_name = "rg-test"
  subscription_id     = "00000000-0000-0000-0000-000000000000"
}

run "retention_and_activity_log" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days >= 90
    error_message = "LOG-001: 90 days minimum."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log.target_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "The subscription Activity Log must be exported."
  }

  assert {
    condition     = length(azurerm_monitor_activity_log_alert.critical) == 0
    error_message = "No alerts without a destination."
  }
}

run "alerts_with_email" {
  command = plan

  variables {
    alert_email = "security@example.com"
  }

  assert {
    condition     = length(azurerm_monitor_activity_log_alert.critical) == 6
    error_message = "Six security-relevant operations are watched."
  }
}

run "rejects_short_retention" {
  command = plan

  variables {
    retention_days = 30
  }

  expect_failures = [var.retention_days]
}
