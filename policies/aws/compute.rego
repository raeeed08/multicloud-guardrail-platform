# CMP-001: compute instances require IMDSv2 (session tokens) so an SSRF bug cannot steal the instance role.
package aws.compute

import rego.v1

import data.lib.core

imdsv2_required(body) if {
	some opts in core.blocks(body, "metadata_options")
	opts.http_tokens == "required"
}

imdsv2_required(body) if {
	some opts in core.blocks(body, "metadata_options")
	core.unknown(opts.http_tokens)
}

deny contains core.msg("CMP-001", "medium", sprintf("%s.%s allows IMDSv1. Add metadata_options { http_tokens = \"required\" }.", [type, name])) if {
	some type in ["aws_instance", "aws_launch_template"]
	some [name, body] in core.resources(type)
	not imdsv2_required(body)
}
