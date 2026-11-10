# CMP-001 key-only SSH, ENC-001 encryption at host (Azure virtual machines).
package azure.compute

import rego.v1

import data.lib.core

deny contains core.msg("CMP-001", "medium", sprintf("azurerm_linux_virtual_machine.%s allows password authentication. Use SSH keys only.", [name])) if {
	some [name, body] in core.resources("azurerm_linux_virtual_machine")
	object.get(body, "disable_password_authentication", true) == false
}

deny contains core.msg("ENC-001", "high", sprintf("%s.%s does not encrypt at host (temp disk and caches stay unencrypted). Set encryption_at_host_enabled = true.", [type, name])) if {
	some type in ["azurerm_linux_virtual_machine", "azurerm_windows_virtual_machine"]
	some [name, body] in core.resources(type)
	core.not_enabled(body, "encryption_at_host_enabled")
}
