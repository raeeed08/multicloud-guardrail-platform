mock_provider "azurerm" {}

variables {
  name                = "kv-lz-test"
  location            = "westeurope"
  resource_group_name = "rg-test"
  tenant_id           = "00000000-0000-0000-0000-000000000000"
}

run "recoverable_private_rbac" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.purge_protection_enabled && azurerm_key_vault.this.rbac_authorization_enabled
    error_message = "KV-001: purge protection and RBAC."
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "KV-001: no public network access."
  }
}

run "rejects_control_plane_roles" {
  command = plan

  variables {
    role_assignments = { admin = { role = "Owner", principal_id = "x" } }
  }

  expect_failures = [var.role_assignments]
}
