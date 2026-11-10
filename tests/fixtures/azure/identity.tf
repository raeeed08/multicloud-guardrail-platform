# rules: IAM-001, IAM-002
# expect: IAM-001
resource "azurerm_role_assignment" "owner" {
  scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
  role_definition_name = "Owner"
  principal_id         = "user"
}

# expect: IAM-001
resource "azurerm_role_assignment" "uaa" {
  scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
  role_definition_name = "User Access Administrator"
  principal_id         = "user"
}

# safe
resource "azurerm_role_assignment" "reader" {
  scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
  role_definition_name = "Reader"
  principal_id         = "scanner"
}

# expect: IAM-002
resource "azuread_application_password" "ci" {
  application_id = "app"
}
