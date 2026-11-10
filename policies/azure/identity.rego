# IAM-001 no standing administrator access, IAM-002 no long-lived credentials (Azure RBAC / Entra ID).
package azure.identity

import rego.v1

import data.lib.core

privileged_roles := {"owner", "user access administrator"}

deny contains core.msg("IAM-001", "high", sprintf("azurerm_role_assignment.%s grants '%s' permanently. Use a narrower role, and Privileged Identity Management for admin tasks.", [name, body.role_definition_name])) if {
	some [name, body] in core.resources("azurerm_role_assignment")
	lower(body.role_definition_name) in privileged_roles
}

deny contains core.msg("IAM-002", "high", sprintf("%s.%s creates a client secret. Use a managed identity or a federated (OIDC) credential.", [type, name])) if {
	some type in ["azuread_application_password", "azuread_service_principal_password"]
	some [name, _] in core.resources(type)
}
