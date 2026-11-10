# NET-001 / NET-002 / NET-003 for Azure Network Security Groups.
# Rules can be written inline (security_rule blocks) or as azurerm_network_security_rule resources,
# with a single value or a list for both the source and the destination port.
package azure.network

import rego.v1

import data.lib.core
import data.lib.net

inbound_rules contains [where, rule] if {
	some [name, nsg] in core.resources("azurerm_network_security_group")
	some rule in core.blocks(nsg, "security_rule")
	where := sprintf("NSG '%s', rule '%s'", [name, rule.name])
}

inbound_rules contains [where, rule] if {
	some [name, rule] in core.resources("azurerm_network_security_rule")
	where := sprintf("azurerm_network_security_rule.%s", [name])
}

exposed(rule) if {
	lower(rule.access) == "allow"
	lower(rule.direction) == "inbound"
	lower(rule.protocol) in {"tcp", "*"}
	some src in array.concat([object.get(rule, "source_address_prefix", "")], object.get(rule, "source_address_prefixes", []))
	net.is_internet(src)
}

port_specs(rule) := array.concat(
	[s | s := object.get(rule, "destination_port_range", null); s != null],
	object.get(rule, "destination_port_ranges", []),
)

opens_all(rule) if {
	some spec in port_specs(rule)
	net.spec_is_all(spec)
}

opens_port(rule, port) if {
	not opens_all(rule)
	some spec in port_specs(rule)
	net.spec_covers(spec, port)
}

deny contains core.msg("NET-001", "critical", sprintf("%s allows SSH/RDP from the internet. Restrict the source or use Azure Bastion.", [where])) if {
	some [where, rule] in inbound_rules
	exposed(rule)
	some port in net.admin_ports
	opens_port(rule, port)
}

deny contains core.msg("NET-002", "critical", sprintf("%s exposes a database/cluster port to the internet. Use a private endpoint.", [where])) if {
	some [where, rule] in inbound_rules
	exposed(rule)
	some port in net.db_ports
	opens_port(rule, port)
}

deny contains core.msg("NET-003", "high", sprintf("%s opens every port to the internet. List explicit ports instead.", [where])) if {
	some [where, rule] in inbound_rules
	exposed(rule)
	opens_all(rule)
}
