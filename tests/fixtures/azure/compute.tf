# rules: CMP-001, ENC-001
# expect: CMP-001
# expect: ENC-001
resource "azurerm_linux_virtual_machine" "password_vm" {
  name                            = "vm-password"
  resource_group_name             = "rg"
  location                        = "westeurope"
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "not-a-real-password"
  disable_password_authentication = false
  network_interface_ids           = ["nic"]
}

# expect: ENC-001
resource "azurerm_windows_virtual_machine" "win" {
  name                  = "vm-win"
  resource_group_name   = "rg"
  location              = "westeurope"
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  admin_password        = "not-a-real-password"
  network_interface_ids = ["nic"]
}

# safe
resource "azurerm_linux_virtual_machine" "hardened" {
  name                       = "vm-hardened"
  resource_group_name        = "rg"
  location                   = "westeurope"
  size                       = "Standard_B2s"
  admin_username             = "azureuser"
  encryption_at_host_enabled = true
  network_interface_ids      = ["nic"]
}
