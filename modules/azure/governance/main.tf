# Control-plane guardrails (the GUARD layer): Azure Policy refuses non-compliant resources at the API,
# whatever tool creates them (portal, CLI, Terraform). Built-in definitions are looked up by display name.
locals {
  scope = "/subscriptions/${var.subscription_id}"
}

data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

data "azurerm_policy_definition" "require_rg_tag" {
  display_name = "Require a tag on resource groups"
}

data "azurerm_policy_definition" "storage_no_public" {
  display_name = "Storage account public access should be disallowed"
}

data "azurerm_policy_definition" "storage_secure_transfer" {
  display_name = "Secure transfer to storage accounts should be enabled"
}

# GOV-001
resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "gov-001-allowed-locations"
  display_name         = "GOV-001 Allowed locations"
  subscription_id      = local.scope
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  enforce              = var.enforce
  parameters           = jsonencode({ listOfAllowedLocations = { value = var.allowed_locations } })

  non_compliance_message {
    content = "GOV-001: resources may only be created in ${join(", ", var.allowed_locations)}."
  }
}

# TAG-001: one assignment per mandatory tag
resource "azurerm_subscription_policy_assignment" "require_tag" {
  for_each             = toset(var.required_tags)
  name                 = "tag-001-${each.value}"
  display_name         = "TAG-001 Require '${each.value}' tag on resource groups"
  subscription_id      = local.scope
  policy_definition_id = data.azurerm_policy_definition.require_rg_tag.id
  enforce              = var.enforce
  parameters           = jsonencode({ tagName = { value = each.value } })

  non_compliance_message {
    content = "TAG-001: every resource group needs the '${each.value}' tag."
  }
}

# STO-001
resource "azurerm_subscription_policy_assignment" "storage_no_public" {
  name                 = "sto-001-no-public-storage"
  display_name         = "STO-001 Storage account public access should be disallowed"
  subscription_id      = local.scope
  policy_definition_id = data.azurerm_policy_definition.storage_no_public.id
  enforce              = var.enforce
  parameters           = jsonencode({ effect = { value = var.effect } })
}

# STO-002
resource "azurerm_subscription_policy_assignment" "storage_secure_transfer" {
  name                 = "sto-002-secure-transfer"
  display_name         = "STO-002 Secure transfer to storage accounts should be enabled"
  subscription_id      = local.scope
  policy_definition_id = data.azurerm_policy_definition.storage_secure_transfer.id
  enforce              = var.enforce
  parameters           = jsonencode({ effect = { value = var.effect } })
}

# Microsoft Defender for Cloud plans (paid). Empty by default for labs; see envs/azure-dev for production values.
resource "azurerm_security_center_subscription_pricing" "plan" {
  for_each      = toset(var.defender_plans)
  tier          = "Standard"
  resource_type = each.value
}

resource "azurerm_security_center_contact" "security" {
  #checkov:skip=CKV_AZURE_20:Alerts go to a shared mailbox; no on-call phone number in a lab.
  count               = var.security_contact_email == null ? 0 : 1
  name                = "security"
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}
