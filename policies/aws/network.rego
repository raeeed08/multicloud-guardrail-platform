# NET-001 / NET-002 / NET-003 for AWS security groups.
# Every way of writing an inbound rule is normalised into one "exposure" record:
#   aws_security_group (inline ingress blocks), aws_security_group_rule (type = ingress),
#   aws_vpc_security_group_ingress_rule (the recommended resource since provider v5).
package aws.network

import rego.v1

import data.lib.core
import data.lib.net

exposures contains e if {
	some [name, sg] in core.resources("aws_security_group")
	some i, rule in core.blocks(sg, "ingress")
	some src in array.concat(object.get(rule, "cidr_blocks", []), object.get(rule, "ipv6_cidr_blocks", []))
	net.is_internet(src)
	e := {
		"where": sprintf("aws_security_group.%s (ingress #%d)", [name, i + 1]),
		"from": object.get(rule, "from_port", null),
		"to": object.get(rule, "to_port", null),
		"proto": object.get(rule, "protocol", ""),
	}
}

exposures contains e if {
	some [name, rule] in core.resources("aws_security_group_rule")
	rule.type == "ingress"
	some src in array.concat(object.get(rule, "cidr_blocks", []), object.get(rule, "ipv6_cidr_blocks", []))
	net.is_internet(src)
	e := {
		"where": sprintf("aws_security_group_rule.%s", [name]),
		"from": object.get(rule, "from_port", null),
		"to": object.get(rule, "to_port", null),
		"proto": object.get(rule, "protocol", ""),
	}
}

exposures contains e if {
	some [name, rule] in core.resources("aws_vpc_security_group_ingress_rule")
	some key in ["cidr_ipv4", "cidr_ipv6"]
	net.is_internet(object.get(rule, key, ""))
	e := {
		"where": sprintf("aws_vpc_security_group_ingress_rule.%s", [name]),
		"from": object.get(rule, "from_port", null),
		"to": object.get(rule, "to_port", null),
		"proto": object.get(rule, "ip_protocol", ""),
	}
}

opens_all(e) if net.protocol_is_all(e.proto)

opens_all(e) if {
	net.protocol_is_tcp_capable(e.proto)
	net.range_is_all(e.from, e.to)
}

opens_port(e, port) if {
	not opens_all(e)
	net.protocol_is_tcp_capable(e.proto)
	net.range_covers(e.from, e.to, port)
}

deny contains core.msg("NET-001", "critical", sprintf("%s allows SSH/RDP from the internet. Restrict the source or use SSM Session Manager.", [e.where])) if {
	some e in exposures
	some port in net.admin_ports
	opens_port(e, port)
}

deny contains core.msg("NET-002", "critical", sprintf("%s exposes a database/cluster port to the internet. Allow it only from the application tier.", [e.where])) if {
	some e in exposures
	some port in net.db_ports
	opens_port(e, port)
}

deny contains core.msg("NET-003", "high", sprintf("%s opens every port to the internet. List explicit ports instead.", [e.where])) if {
	some e in exposures
	opens_all(e)
}
