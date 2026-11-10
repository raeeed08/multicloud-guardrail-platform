# rules: NET-001, NET-002, NET-003
resource "azurerm_network_security_group" "cases" {
  name                = "nsg-test-cases"
  location            = "westeurope"
  resource_group_name = "rg-test"

  # expect: NET-001
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

  # expect: NET-001
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

  # expect: NET-001
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

  # expect: NET-002
  security_rule {
    name                       = "sql-from-anywhere"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # expect: NET-003
  security_rule {
    name                       = "any-port"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # safe: SSH from one trusted address only
  security_rule {
    name                       = "ssh-from-trusted-ip"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "203.0.113.10/32"
    destination_address_prefix = "*"
  }

  # safe: deny rules are the goal
  security_rule {
    name                       = "deny-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# expect: NET-002
resource "azurerm_network_security_rule" "redis_public" {
  name                        = "redis"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6379"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = "rg-test"
  network_security_group_name = "nsg-test-cases"
}

# safe: outbound traffic is not exposure
resource "azurerm_network_security_rule" "outbound_https" {
  name                        = "out-https"
  priority                    = 210
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = "rg-test"
  network_security_group_name = "nsg-test-cases"
}
