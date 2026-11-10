# rules: LOG-001
# expect: LOG-001
resource "azurerm_log_analytics_workspace" "default_retention" {
  name                = "law-default"
  location            = "westeurope"
  resource_group_name = "rg"
}

# expect: LOG-001
resource "azurerm_log_analytics_workspace" "short" {
  name                = "law-short"
  location            = "westeurope"
  resource_group_name = "rg"
  retention_in_days   = 31
}

# safe
resource "azurerm_log_analytics_workspace" "audit" {
  name                = "law-audit"
  location            = "westeurope"
  resource_group_name = "rg"
  retention_in_days   = 90
}
