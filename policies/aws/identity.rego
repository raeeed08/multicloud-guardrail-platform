# IAM-001 no standing administrator access, IAM-002 no long-lived credentials (AWS IAM).
package aws.identity

import rego.v1

import data.lib.core

attachment_types := {
	"aws_iam_user_policy_attachment",
	"aws_iam_role_policy_attachment",
	"aws_iam_group_policy_attachment",
	"aws_iam_policy_attachment",
}

admin_policy(arn) if endswith(arn, ":policy/AdministratorAccess")

deny contains core.msg("IAM-001", "high", sprintf("%s.%s attaches AdministratorAccess. Grant a least-privilege policy; use short-lived elevation for admin work.", [type, name])) if {
	some type in attachment_types
	some [name, body] in core.resources(type)
	admin_policy(body.policy_arn)
}

deny contains core.msg("IAM-002", "high", sprintf("aws_iam_access_key.%s creates a long-lived access key. Use an IAM role or OIDC federation instead.", [name])) if {
	some [name, _] in core.resources("aws_iam_access_key")
}
