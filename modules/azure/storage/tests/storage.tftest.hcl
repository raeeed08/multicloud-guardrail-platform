mock_provider "azurerm" {}

variables {
  name                = "stlztest001"
  resource_group_name = "rg-test"
  location            = "westeurope"
  containers          = ["data", "exports"]
}

run "private_by_default" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false
    error_message = "STO-001: no public containers."
  }

  assert {
    condition     = azurerm_storage_account.this.public_network_access_enabled == false
    error_message = "STO-003: private endpoint only."
  }

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2" && azurerm_storage_account.this.https_traffic_only_enabled
    error_message = "STO-002: HTTPS and TLS 1.2."
  }

  assert {
    condition     = azurerm_storage_account.this.shared_access_key_enabled == false
    error_message = "Account keys must be disabled (Entra ID only)."
  }

  assert {
    condition     = alltrue([for c in azurerm_storage_container.this : c.container_access_type == "private"])
    error_message = "Containers are private."
  }

  assert {
    condition     = length(azurerm_private_endpoint.blob) == 0
    error_message = "No endpoint without a subnet."
  }
}

run "private_endpoint_when_subnet_given" {
  command = plan

  variables {
    private_endpoint_subnet_id = "/subscriptions/0/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/v/subnets/pe"
  }

  assert {
    condition     = one(azurerm_private_endpoint.blob[0].private_service_connection).subresource_names == tolist(["blob"])
    error_message = "The endpoint must target the blob sub-resource."
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "St-Invalid"
  }

  expect_failures = [var.name]
}
