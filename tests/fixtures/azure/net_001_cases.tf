resource "azurerm_network_security_group" "cases" {
  name                = "nsg-test-cases"
  location            = "westeurope"
  resource_group_name = "rg-test"

  # MUST be flagged: SSH from anywhere
  security_rule {
    name                       = "ssh-from-anywhere"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # MUST be flagged: RDP hidden inside a list of ports
  security_rule {
    name                       = "rdp-in-port-list"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "3389"]
    source_address_prefixes    = ["Internet"]
    destination_address_prefix = "*"
  }

  # MUST be flagged: wide port range that includes 22
  security_rule {
    name                       = "wide-port-range"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "0-1024"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  # MUST NOT be flagged: SSH from one trusted address only
  security_rule {
    name                       = "ssh-from-trusted-ip"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "203.0.113.10/32"
    destination_address_prefix = "*"
  }
}
