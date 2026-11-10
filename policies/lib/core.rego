# Shared helpers for every policy.
#
# Conftest parses Terraform (HCL2) into JSON:
#   input.resource.<type>.<name> = [ { ...attributes, nested blocks as lists... } ]
#   input.provider.<name>        = [ { ... } ]
# Values that reference variables or other resources arrive as strings such as "${var.encrypted}".
# Policies treat those as UNKNOWN and do not fail on them: the code cannot tell what they will be.
# The deployed value is checked at runtime by Cloud Copilot (see rulebook/rules.yaml, detect).
package lib.core

import rego.v1

# Every resource of a type, as [name, body] pairs.
resources(type) := {[name, body] |
	some name, bodies in input.resource[type]
	some body in bodies
}

# A value that is an unresolved Terraform expression.
unknown(v) if {
	is_string(v)
	contains(v, "${")
}

# True when an attribute is explicitly true, or unknown (benefit of the doubt).
true_or_unknown(v) if v == true

true_or_unknown(v) if unknown(v)

# The attribute must be true; missing means the provider default (false).
not_enabled(body, key) if not true_or_unknown(object.get(body, key, false))

# The attribute must be false; missing means the provider default (true).
not_disabled(body, key) if {
	v := object.get(body, key, true)
	v != false
	not unknown(v)
}

# A nested block (list of objects), or an empty list when absent.
blocks(body, key) := object.get(body, key, [])

# Standard message format: "<RULE-ID> [<severity>]: <text>"
msg(rule_id, severity, text) := sprintf("%s [%s]: %s", [rule_id, severity, text])
