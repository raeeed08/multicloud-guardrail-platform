output "client_id" {
  description = "Set as AZURE_CLIENT_ID in the GitHub environment (not a secret)."
  value       = azurerm_user_assigned_identity.github.client_id
}

output "principal_id" {
  value = azurerm_user_assigned_identity.github.principal_id
}
