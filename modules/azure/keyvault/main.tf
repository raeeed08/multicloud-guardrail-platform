# Key Vault with RBAC (no access policies), purge protection, no public network access, and audit logs.
resource "azurerm_key_vault" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = var.sku_name
  rbac_authorization_enabled    = true # KV-001
  purge_protection_enabled      = true # KV-001
  soft_delete_retention_days    = 90
  public_network_access_enabled = false # KV-001

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "vault" {
  count               = var.private_endpoint_subnet_id == null ? 0 : 1
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "vault"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "audit" {
  count                      = var.log_analytics_workspace_id == null ? 0 : 1
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
}

# Least-privilege data-plane access: one role per principal, chosen by the caller.
resource "azurerm_role_assignment" "access" {
  for_each             = var.role_assignments
  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
}
