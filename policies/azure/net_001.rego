package azure.net_001

import rego.v1

# NET-001: No SSH (22) or RDP (3389) open to the internet.
# Reads Terraform code (HCL parsed by Conftest). Variables are not resolved here;
# runtime detection by the copilot covers actual deployed values.

admin_ports := {22, 3389}

internet_sources := {"*", "internet", "any", "0.0.0.0/0"}

# ---- source is the internet ----
source_is_internet(rule) if {
lower(rule.source_address_prefix) in internet_sources
}

source_is_internet(rule) if {
some prefix in rule.source_address_prefixes
lower(prefix) in internet_sources
}

# ---- a port specification covers an admin port ----
port_exposes_admin(spec) if {
spec == "*"
}

port_exposes_admin(spec) if {
to_number(spec) in admin_ports
}

port_exposes_admin(spec) if {
parts := split(spec, "-")
count(parts) == 2
low := to_number(parts[0])
high := to_number(parts[1])
some port in admin_ports
low <= port
port <= high
}

# ---- an inbound, allowing, TCP-capable rule ----
inbound_allow_tcp(rule) if {
lower(rule.access) == "allow"
lower(rule.direction) == "inbound"
lower(rule.protocol) in {"tcp", "*"}
}

rule_exposes_admin(rule) if {
inbound_allow_tcp(rule)
source_is_internet(rule)
port_exposes_admin(rule.destination_port_range)
}

rule_exposes_admin(rule) if {
inbound_allow_tcp(rule)
source_is_internet(rule)
some spec in rule.destination_port_ranges
port_exposes_admin(spec)
}

# ---- violations: rules written inside an NSG ----
deny contains msg if {
some name, nsg_list in input.resource.azurerm_network_security_group
some nsg in nsg_list
some rule in nsg.security_rule
rule_exposes_admin(rule)
msg := sprintf("NET-001 [high]: NSG '%s', rule '%s' allows SSH/RDP from the internet. Restrict the source range or remove the rule.", [name, rule.name])
}

# ---- violations: standalone rule resources ----
deny contains msg if {
some name, rule_list in input.resource.azurerm_network_security_rule
some rule in rule_list
rule_exposes_admin(rule)
msg := sprintf("NET-001 [high]: security rule resource '%s' allows SSH/RDP from the internet. Restrict the source range or remove the rule.", [name])
}
