output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe.id
}

output "mgmt_subnet_id" {
  value = azurerm_subnet.mgmt.id
}
