output "policy_assignment_ids" {
  value = concat(
    [azurerm_subscription_policy_assignment.allowed_locations.id],
    [for a in azurerm_subscription_policy_assignment.require_tag : a.id],
    [azurerm_subscription_policy_assignment.storage_no_public.id, azurerm_subscription_policy_assignment.storage_secure_transfer.id],
  )
}
