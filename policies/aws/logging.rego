# LOG-001: audit logs are complete, tamper-evident and retained (CloudTrail, CloudWatch Logs).
package aws.logging

import rego.v1

import data.lib.core

min_retention_days := 90

trail_checks := [
	["is_multi_region_trail", "not multi-region"],
	["enable_log_file_validation", "no log file validation"],
]

kms_gap(body) := {"no KMS encryption"} if not object.get(body, "kms_key_id", false)

kms_gap(body) := set() if object.get(body, "kms_key_id", false)

trail_gaps(body) := {gap | some [key, gap] in trail_checks; core.not_enabled(body, key)} | kms_gap(body)

deny contains core.msg("LOG-001", "high", sprintf("aws_cloudtrail.%s has gaps: %s.", [name, concat(", ", sort(gaps))])) if {
	some [name, body] in core.resources("aws_cloudtrail")
	gaps := trail_gaps(body)
	count(gaps) > 0
}

# 0 or missing = logs never expire (cost), below the minimum = evidence lost too early.
retention_problem(body) := "never expires (cost grows forever)" if {
	object.get(body, "retention_in_days", 0) == 0
}

retention_problem(body) := sprintf("keeps logs only %d days (minimum %d)", [days, min_retention_days]) if {
	days := object.get(body, "retention_in_days", 0)
	is_number(days)
	days > 0
	days < min_retention_days
}

deny contains core.msg("LOG-001", "high", sprintf("aws_cloudwatch_log_group.%s %s. Set retention_in_days between %d and 3653.", [name, problem, min_retention_days])) if {
	some [name, body] in core.resources("aws_cloudwatch_log_group")
	problem := retention_problem(body)
}
