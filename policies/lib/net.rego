# Network helpers shared by the AWS and Azure network policies (NET-001, NET-002, NET-003).
package lib.net

import rego.v1

admin_ports := {22, 3389}

# SQL Server, Oracle, MySQL, PostgreSQL, CouchDB, Redis, Elasticsearch, MongoDB
db_ports := {1433, 1521, 3306, 5432, 5984, 6379, 9200, 27017}

internet_sources := {"*", "internet", "any", "0.0.0.0/0", "::/0"}

is_internet(src) if lower(src) in internet_sources

# ---------- numeric ranges (AWS from_port / to_port) ----------

range_covers(from, to, port) if {
	is_number(from)
	is_number(to)
	from <= port
	port <= to
}

range_is_all(from, to) if {
	is_number(from)
	is_number(to)
	from <= 0
	to >= 65535
}

# AWS protocol "-1" / "all" means every protocol and every port.
protocol_is_all(p) if lower(sprintf("%v", [p])) in {"-1", "all"}

protocol_is_tcp_capable(p) if lower(sprintf("%v", [p])) in {"tcp", "6", "-1", "all"}

# ---------- port specifications (Azure: "22", "20-30", "*") ----------

spec_is_all(spec) if spec == "*"

spec_is_all(spec) if spec == "0-65535"

spec_covers(spec, port) if spec_is_all(spec)

spec_covers(spec, port) if to_number(spec) == port

spec_covers(spec, port) if {
	parts := split(spec, "-")
	count(parts) == 2
	to_number(parts[0]) <= port
	port <= to_number(parts[1])
}
