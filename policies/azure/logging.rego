# LOG-001: logs are retained long enough to investigate an incident (Log Analytics, default 30 days).
package azure.logging

import rego.v1

import data.lib.core

min_retention_days := 90

deny contains core.msg("LOG-001", "high", sprintf("azurerm_log_analytics_workspace.%s keeps logs %v days (minimum %d). Set retention_in_days.", [name, days, min_retention_days])) if {
	some [name, body] in core.resources("azurerm_log_analytics_workspace")
	days := object.get(body, "retention_in_days", 30)
	is_number(days)
	days < min_retention_days
}
