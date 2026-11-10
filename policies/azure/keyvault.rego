# KV-001 recoverable and private Key Vaults, ENC-002 key rotation (Azure Key Vault).
package azure.keyvault

import rego.v1

import data.lib.core

# azurerm 4.x renamed enable_rbac_authorization to rbac_authorization_enabled; accept both.
uses_rbac(body) if core.true_or_unknown(object.get(body, "rbac_authorization_enabled", false))

uses_rbac(body) if core.true_or_unknown(object.get(body, "enable_rbac_authorization", false))

network_restricted(body) if not core.not_disabled(body, "public_network_access_enabled")

network_restricted(body) if {
	some acl in core.blocks(body, "network_acls")
	lower(acl.default_action) == "deny"
}

deny contains core.msg("KV-001", "medium", sprintf("azurerm_key_vault.%s: %s.", [name, concat(", ", sort(problems))])) if {
	some [name, body] in core.resources("azurerm_key_vault")
	problems := {p | some p in ["purge protection disabled", "access policies instead of RBAC", "reachable from all networks"]; fails(body, p)}
	count(problems) > 0
}

fails(body, "purge protection disabled") if core.not_enabled(body, "purge_protection_enabled")

fails(body, "access policies instead of RBAC") if not uses_rbac(body)

fails(body, "reachable from all networks") if not network_restricted(body)

deny contains core.msg("ENC-002", "medium", sprintf("azurerm_key_vault_key.%s has no rotation_policy. Rotate keys automatically.", [name])) if {
	some [name, body] in core.resources("azurerm_key_vault_key")
	count(core.blocks(body, "rotation_policy")) == 0
}
