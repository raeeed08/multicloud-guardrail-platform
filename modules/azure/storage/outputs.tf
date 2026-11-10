output "id" {
  value = azurerm_storage_account.this.id
}

output "name" {
  value = azurerm_storage_account.this.name
}

output "principal_id" {
  description = "System-assigned identity, for customer-managed key access."
  value       = azurerm_storage_account.this.identity[0].principal_id
}
