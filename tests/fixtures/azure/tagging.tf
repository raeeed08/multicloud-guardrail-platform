# rules: TAG-001
# expect: TAG-001
resource "azurerm_resource_group" "untagged" {
  name     = "rg-untagged"
  location = "westeurope"
}

# expect: TAG-001
resource "azurerm_resource_group" "partial" {
  name     = "rg-partial"
  location = "westeurope"
  tags     = { owner = "platform" }
}

# safe
resource "azurerm_resource_group" "tagged" {
  name     = "rg-tagged"
  location = "westeurope"
  tags     = { owner = "platform", environment = "dev", project = "landing-zone" }
}

# safe: tags from a variable, checked at runtime
resource "azurerm_resource_group" "from_var" {
  name     = "rg-var"
  location = "westeurope"
  tags     = var.tags
}
