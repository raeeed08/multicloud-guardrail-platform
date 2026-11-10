# DB-001: databases are never publicly reachable (Azure SQL, PostgreSQL Flexible Server).
package azure.database

import rego.v1

import data.lib.core

deny contains core.msg("DB-001", "critical", sprintf("azurerm_mssql_server.%s accepts connections from public networks. Set public_network_access_enabled = false and use a private endpoint.", [name])) if {
	some [name, body] in core.resources("azurerm_mssql_server")
	core.not_disabled(body, "public_network_access_enabled")
}

deny contains core.msg("DB-001", "critical", sprintf("azurerm_mssql_firewall_rule.%s allows every IP address (0.0.0.0-255.255.255.255).", [name])) if {
	some [name, body] in core.resources("azurerm_mssql_firewall_rule")
	body.start_ip_address == "0.0.0.0"
	body.end_ip_address == "255.255.255.255"
}

# A server injected into a VNet (delegated subnet) has no public endpoint.
deny contains core.msg("DB-001", "critical", sprintf("azurerm_postgresql_flexible_server.%s has a public endpoint. Use VNet integration (delegated_subnet_id) or a private endpoint.", [name])) if {
	some [name, body] in core.resources("azurerm_postgresql_flexible_server")
	core.not_disabled(body, "public_network_access_enabled")
	not body.delegated_subnet_id
}
