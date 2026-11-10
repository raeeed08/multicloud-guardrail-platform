# rules: STO-001, STO-002, STO-003
# expect: STO-001
# expect: STO-003
resource "azurerm_storage_account" "defaults" {
  name                     = "stdefaults"
  resource_group_name      = "rg"
  location                 = "westeurope"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# expect: STO-002
resource "azurerm_storage_account" "plain_http" {
  name                            = "stplainhttp"
  resource_group_name             = "rg"
  location                        = "westeurope"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  https_traffic_only_enabled      = false
}

# expect: STO-002
resource "azurerm_storage_account" "old_tls" {
  name                            = "stoldtls"
  resource_group_name             = "rg"
  location                        = "westeurope"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_0"
  network_rules {
    default_action = "Deny"
  }
}

# safe
resource "azurerm_storage_account" "secure" {
  name                            = "stsecure"
  resource_group_name             = "rg"
  location                        = "westeurope"
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  min_tls_version                 = "TLS1_2"
}
