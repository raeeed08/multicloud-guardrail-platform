package lib.net_test

import rego.v1

import data.lib.core
import data.lib.net

test_internet_sources if {
	net.is_internet("0.0.0.0/0")
	net.is_internet("Internet")
	net.is_internet("::/0")
	not net.is_internet("10.0.0.0/16")
	not net.is_internet("203.0.113.10/32")
}

test_numeric_ranges if {
	net.range_covers(0, 1024, 22)
	not net.range_covers(80, 443, 22)
	net.range_is_all(0, 65535)
	not net.range_is_all(0, 1024)
	not net.range_covers("${var.from}", 30, 22)
}

test_protocols if {
	net.protocol_is_all("-1")
	net.protocol_is_all(-1)
	net.protocol_is_tcp_capable("TCP")
	not net.protocol_is_tcp_capable("udp")
}

test_port_specs if {
	net.spec_covers("22", 22)
	net.spec_covers("20-30", 22)
	net.spec_covers("*", 3389)
	not net.spec_covers("80", 22)
	not net.spec_covers("3000-3300", 3389)
	net.spec_is_all("*")
}

test_unknown_values_get_benefit_of_doubt if {
	core.unknown("${var.encrypted}")
	not core.unknown("TLS1_2")
	core.not_enabled({}, "encrypted")
	core.not_enabled({"encrypted": false}, "encrypted")
	not core.not_enabled({"encrypted": true}, "encrypted")
	not core.not_enabled({"encrypted": "${var.x}"}, "encrypted")
	core.not_disabled({}, "public")
	not core.not_disabled({"public": false}, "public")
	not core.not_disabled({"public": "${var.p}"}, "public")
}
