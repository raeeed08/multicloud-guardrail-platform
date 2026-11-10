# rules: KV-001, ENC-002
# expect: KV-001
resource "azurerm_key_vault" "defaults" {
  name                = "kv-defaults"
  location            = "westeurope"
  resource_group_name = "rg"
  tenant_id           = "00000000-0000-0000-0000-000000000000"
  sku_name            = "standard"
}

# safe
resource "azurerm_key_vault" "secure" {
  name                          = "kv-secure"
  location                      = "westeurope"
  resource_group_name           = "rg"
  tenant_id                     = "00000000-0000-0000-0000-000000000000"
  sku_name                      = "standard"
  purge_protection_enabled      = true
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
}

# expect: ENC-002
resource "azurerm_key_vault_key" "static" {
  name         = "data"
  key_vault_id = "kv"
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["encrypt", "decrypt"]
}

# safe
resource "azurerm_key_vault_key" "rotated" {
  name         = "data-rotated"
  key_vault_id = "kv"
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["encrypt", "decrypt"]
  rotation_policy {
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"
    automatic {
      time_before_expiry = "P30D"
    }
  }
}
