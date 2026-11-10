# Lets a GitHub Actions workflow deploy to Azure WITHOUT any stored secret (IAM-002):
# GitHub issues a short-lived OIDC token, Entra ID trusts it only for the given repository and environment,
# and exchanges it for a token of this managed identity.
resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.name_prefix}-github"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each                  = toset(var.subjects)
  name                      = substr(replace(each.value, "/[^a-zA-Z0-9-]/", "-"), 0, 120)
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = each.value
}

resource "azurerm_role_assignment" "github" {
  for_each             = var.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}
