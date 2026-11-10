# TAG-001: every resource group carries owner / environment / project tags (Azure Policy enforces it at runtime).
package azure.tagging

import rego.v1

import data.lib.core

required_tags := {"owner", "environment", "project"}

missing_tags(body) := required_tags if not body.tags

missing_tags(body) := {t | some t in required_tags; not object.get(body.tags, t, false)} if is_object(body.tags)

missing_tags(body) := set() if core.unknown(body.tags)

deny contains core.msg("TAG-001", "low", sprintf("azurerm_resource_group.%s is missing tags: %s.", [name, concat(", ", sort(missing))])) if {
	some [name, body] in core.resources("azurerm_resource_group")
	missing := missing_tags(body)
	count(missing) > 0
}
