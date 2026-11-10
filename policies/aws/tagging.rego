# TAG-001: every AWS resource inherits owner / environment / project tags from the provider's default_tags.
package aws.tagging

import rego.v1

import data.lib.core

required_tags := {"owner", "environment", "project"}

default_tags(provider) := tags if {
	some block in core.blocks(provider, "default_tags")
	tags := object.get(block, "tags", {})
}

missing_tags(provider) := required_tags if not default_tags(provider)

missing_tags(provider) := {t | some t in required_tags; not object.get(tags, t, false)} if {
	tags := default_tags(provider)
	is_object(tags)
}

missing_tags(provider) := set() if {
	core.unknown(default_tags(provider))
}

deny contains core.msg("TAG-001", "low", sprintf("provider \"aws\"%s is missing default tags: %s.", [alias_label(provider), concat(", ", sort(missing))])) if {
	some provider in object.get(object.get(input, "provider", {}), "aws", [])
	missing := missing_tags(provider)
	count(missing) > 0
}

alias_label(provider) := sprintf(" (alias %s)", [provider.alias]) if provider.alias

alias_label(provider) := "" if not provider.alias
