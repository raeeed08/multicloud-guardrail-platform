# STO-001 never public, STO-002 encrypted connections, STO-003 not open to all networks (Azure Storage).
# Provider defaults (azurerm 4.x): allow_nested_items_to_be_public = true, public_network_access_enabled = true,
# https_traffic_only_enabled = true, min_tls_version = "TLS1_2". Safe defaults are trusted, unsafe ones are not.
package azure.storage

import rego.v1

import data.lib.core

deny contains core.msg("STO-001", "critical", sprintf("azurerm_storage_account.%s allows public blob containers. Set allow_nested_items_to_be_public = false.", [name])) if {
	some [name, body] in core.resources("azurerm_storage_account")
	core.not_disabled(body, "allow_nested_items_to_be_public")
}

weak_transport(body) := "accepts plain HTTP" if object.get(body, "https_traffic_only_enabled", true) == false

weak_transport(body) := sprintf("allows %s", [body.min_tls_version]) if {
	object.get(body, "https_traffic_only_enabled", true) != false
	body.min_tls_version in {"TLS1_0", "TLS1_1"}
}

deny contains core.msg("STO-002", "medium", sprintf("azurerm_storage_account.%s %s. Require HTTPS and TLS 1.2.", [name, problem])) if {
	some [name, body] in core.resources("azurerm_storage_account")
	problem := weak_transport(body)
}

network_restricted(body) if {
	some rules in core.blocks(body, "network_rules")
	lower(rules.default_action) == "deny"
}

network_restricted(body) if {
	some rules in core.blocks(body, "network_rules")
	core.unknown(rules.default_action)
}

deny contains core.msg("STO-003", "medium", sprintf("azurerm_storage_account.%s is reachable from all networks. Disable public network access or set network_rules default_action = \"Deny\".", [name])) if {
	some [name, body] in core.resources("azurerm_storage_account")
	core.not_disabled(body, "public_network_access_enabled")
	not network_restricted(body)
}
