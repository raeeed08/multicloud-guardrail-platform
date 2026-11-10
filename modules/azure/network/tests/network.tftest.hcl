mock_provider "azurerm" {}

variables {
  name_prefix         = "lz-test"
  location            = "westeurope"
  resource_group_name = "rg-test"
}

run "default_deny_where_it_matters" {
  command = plan

  assert {
    condition     = anytrue([for r in azurerm_network_security_group.mgmt.security_rule : r.access == "Deny" && r.source_address_prefix == "*"])
    error_message = "The management subnet must deny all inbound traffic."
  }

  assert {
    condition     = alltrue([for r in azurerm_network_security_group.app.security_rule : r.destination_port_range == "443"])
    error_message = "The app subnet only opens HTTPS."
  }

  assert {
    condition     = azurerm_subnet.pe.private_endpoint_network_policies == "Enabled"
    error_message = "NSGs must apply to private endpoints."
  }
}
