# Central logging for the subscription: Log Analytics workspace (90+ days), the subscription Activity Log
# streamed into it, and alerts on the control-plane operations attackers use to weaken security.
resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days # LOG-001
  daily_quota_gb      = var.daily_quota_gb # FinOps: cap ingestion cost (-1 = unlimited)
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-log-to-law"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "Policy", "Alert", "ServiceHealth", "Recommendation", "ResourceHealth", "Autoscale"]
    content {
      category = enabled_log.value
    }
  }
}

resource "azurerm_monitor_action_group" "security" {
  count               = var.alert_email == null ? 0 : 1
  name                = "ag-${var.name_prefix}-security"
  resource_group_name = var.resource_group_name
  short_name          = "security"
  tags                = var.tags

  email_receiver {
    name                    = "security-team"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

locals {
  # CIS Azure 5.2.x: alert on changes that open the network or remove guardrails.
  watched_operations = {
    nsg-rule-write        = "Microsoft.Network/networkSecurityGroups/securityRules/write"
    nsg-rule-delete       = "Microsoft.Network/networkSecurityGroups/securityRules/delete"
    policy-assignment-del = "Microsoft.Authorization/policyAssignments/delete"
    role-assignment-write = "Microsoft.Authorization/roleAssignments/write"
    keyvault-delete       = "Microsoft.KeyVault/vaults/delete"
    sql-firewall-write    = "Microsoft.Sql/servers/firewallRules/write"
  }
}

resource "azurerm_monitor_activity_log_alert" "critical" {
  for_each            = var.alert_email == null ? {} : local.watched_operations
  name                = "ala-${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Security-relevant operation: ${each.value}"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = each.value
  }

  action {
    action_group_id = azurerm_monitor_action_group.security[0].id
  }
}
