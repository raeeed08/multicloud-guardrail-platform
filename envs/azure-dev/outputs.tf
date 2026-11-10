output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "log_analytics_workspace_id" {
  value = module.monitoring.workspace_id
}

output "key_vault_uri" {
  value = module.keyvault.uri
}

output "storage_account" {
  value = module.storage.name
}

output "github_client_id" {
  description = "AZURE_CLIENT_ID for the GitHub environment."
  value       = module.github_oidc.client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
