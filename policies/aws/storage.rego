# STO-001: object storage is never public (S3).
package aws.storage

import rego.v1

import data.lib.core

bpa_settings := ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]

missing_bpa(body) := [k | some k in bpa_settings; core.not_enabled(body, k)]

deny contains core.msg("STO-001", "critical", sprintf("aws_s3_bucket_public_access_block.%s does not enable %s. Enable all four settings.", [name, concat(", ", missing)])) if {
	some [name, body] in core.resources("aws_s3_bucket_public_access_block")
	missing := missing_bpa(body)
	count(missing) > 0
}

deny contains core.msg("STO-001", "critical", sprintf("aws_s3_account_public_access_block.%s does not enable %s. The account-level block is the safety net for every bucket.", [name, concat(", ", missing)])) if {
	some [name, body] in core.resources("aws_s3_account_public_access_block")
	missing := missing_bpa(body)
	count(missing) > 0
}

deny contains core.msg("STO-001", "critical", sprintf("aws_s3_bucket_acl.%s uses the public ACL '%s'. Use bucket policies and BucketOwnerEnforced ownership.", [name, body.acl])) if {
	some [name, body] in core.resources("aws_s3_bucket_acl")
	body.acl in {"public-read", "public-read-write", "authenticated-read"}
}
