# ENC-001 encryption at rest, ENC-002 key rotation, KV-001 recoverable secrets (AWS).
package aws.encryption

import rego.v1

import data.lib.core

encrypted_attribute := {
	"aws_ebs_volume": "encrypted",
	"aws_db_instance": "storage_encrypted",
	"aws_rds_cluster": "storage_encrypted",
}

deny contains core.msg("ENC-001", "high", sprintf("%s.%s is not encrypted at rest. Set %s = true.", [type, name, attr])) if {
	some type, attr in encrypted_attribute
	some [name, body] in core.resources(type)
	core.not_enabled(body, attr)
}

# Automatic rotation only exists for symmetric keys.
symmetric(body) if object.get(body, "customer_master_key_spec", "SYMMETRIC_DEFAULT") == "SYMMETRIC_DEFAULT"

symmetric(body) if core.unknown(object.get(body, "customer_master_key_spec", ""))

deny contains core.msg("ENC-002", "medium", sprintf("aws_kms_key.%s does not rotate automatically. Set enable_key_rotation = true.", [name])) if {
	some [name, body] in core.resources("aws_kms_key")
	symmetric(body)
	core.not_enabled(body, "enable_key_rotation")
}

deny contains core.msg("KV-001", "medium", sprintf("aws_secretsmanager_secret.%s is deleted immediately (recovery_window_in_days = 0). Keep a 7-30 day recovery window.", [name])) if {
	some [name, body] in core.resources("aws_secretsmanager_secret")
	object.get(body, "recovery_window_in_days", 30) == 0
}
