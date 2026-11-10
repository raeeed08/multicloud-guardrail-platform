# Private-by-default storage account: no public containers, no shared keys (Entra ID only), TLS 1.2,
# reachable only through a private endpoint, with soft delete and versioning for recovery.
resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV2_AZURE_1:Infrastructure (double) encryption with platform keys; customer-managed keys are a documented next step.
  #checkov:skip=CKV_AZURE_206:Replication is a variable (default ZRS); the dev environment uses LRS for cost.
  #checkov:skip=CKV_AZURE_33:No queues are used by this module.
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false # STO-001
  public_network_access_enabled     = false # STO-003: private endpoint only
  shared_access_key_enabled         = false # identities instead of account keys
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true # double encryption at rest
  cross_tenant_replication_enabled  = false

  identity {
    type = "SystemAssigned"
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = var.soft_delete_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_days
    }
  }

  sas_policy {
    expiration_period = "01.00:00:00"
    expiration_action = "Log"
  }

  tags = var.tags
}

# Created through the management plane (storage_account_id), so it works with public access disabled.
resource "azurerm_storage_container" "this" {
  #checkov:skip=CKV2_AZURE_21:Blob read/write/delete logs are exported by azurerm_monitor_diagnostic_setting.blob.
  for_each              = toset(var.containers)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "blob" {
  count               = var.private_endpoint_subnet_id == null ? 0 : 1
  name                = "pe-${var.name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "blob"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  count                      = var.log_analytics_workspace_id == null ? 0 : 1
  name                       = "to-log-analytics"
  target_resource_id         = "${azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }
}
