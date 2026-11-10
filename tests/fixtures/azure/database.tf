# rules: DB-001
# expect: DB-001
resource "azurerm_mssql_server" "public" {
  name                = "sql-public"
  resource_group_name = "rg"
  location            = "westeurope"
  version             = "12.0"
}

# safe
resource "azurerm_mssql_server" "private" {
  name                          = "sql-private"
  resource_group_name           = "rg"
  location                      = "westeurope"
  version                       = "12.0"
  public_network_access_enabled = false
}

# expect: DB-001
resource "azurerm_mssql_firewall_rule" "everyone" {
  name             = "allow-all"
  server_id        = "sql"
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# safe
resource "azurerm_mssql_firewall_rule" "office" {
  name             = "office"
  server_id        = "sql"
  start_ip_address = "203.0.113.10"
  end_ip_address   = "203.0.113.10"
}

# expect: DB-001
resource "azurerm_postgresql_flexible_server" "public" {
  name                = "pg-public"
  resource_group_name = "rg"
  location            = "westeurope"
  version             = "16"
}

# safe: VNet-integrated server has no public endpoint
resource "azurerm_postgresql_flexible_server" "vnet" {
  name                          = "pg-vnet"
  resource_group_name           = "rg"
  location                      = "westeurope"
  version                       = "16"
  delegated_subnet_id           = "subnet-id"
  private_dns_zone_id           = "zone-id"
  public_network_access_enabled = false
}
