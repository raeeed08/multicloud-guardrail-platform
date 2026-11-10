# DB-001: databases are never publicly reachable (RDS).
package aws.database

import rego.v1

import data.lib.core

deny contains core.msg("DB-001", "critical", sprintf("aws_db_instance.%s is publicly accessible. Set publicly_accessible = false and reach it from private subnets.", [name])) if {
	some [name, body] in core.resources("aws_db_instance")
	object.get(body, "publicly_accessible", false) == true
}
