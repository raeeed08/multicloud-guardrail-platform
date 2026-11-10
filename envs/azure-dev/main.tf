# Azure landing zone for one workload subscription (dev).
#   governance  -> Azure Policy guardrails (GUARD layer) + Defender plans
#   monitoring  -> Log Analytics + Activity Log + security alerts
#   network     -> VNet with app / private-endpoint / management subnets, default-deny NSGs
#   keyvault    -> secrets, private endpoint only
#   storage     -> private data account, private endpoint only
#   github-oidc -> secretless CI/CD identity
terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Remote state: see backend.hcl.example (terraform init -backend-config=backend.hcl)
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id     = var.subscription_id
  storage_use_azuread = true # shared keys are disabled on our storage accounts
}

data "azurerm_client_config" "current" {}

locals {
  tags = merge(var.tags, { environment = var.environment })
  # Storage and Key Vault names are global: derive a short stable suffix from the subscription.
  suffix = substr(sha1(var.subscription_id), 0, 6)
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "governance" {
  source                 = "../../modules/azure/governance"
  subscription_id        = var.subscription_id
  allowed_locations      = var.allowed_locations
  enforce                = var.enforce_policies
  defender_plans         = var.defender_plans
  security_contact_email = var.security_email
}

module "monitoring" {
  source              = "../../modules/azure/monitoring"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subscription_id     = var.subscription_id
  alert_email         = var.security_email
  tags                = local.tags
}

module "network" {
  source              = "../../modules/azure/network"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "keyvault" {
  source                     = "../../modules/azure/keyvault"
  name                       = "kv-${replace(var.name_prefix, "-", "")}-${local.suffix}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.network.pe_subnet_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = local.tags
}

module "storage" {
  source                     = "../../modules/azure/storage"
  name                       = "st${replace(var.name_prefix, "-", "")}${local.suffix}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  replication_type           = var.storage_replication
  containers                 = ["data"]
  private_endpoint_subnet_id = module.network.pe_subnet_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = local.tags
}

module "github_oidc" {
  source              = "../../modules/azure/github-oidc"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subjects            = ["repo:${var.github_repository}:environment:${var.environment}"]
  role_assignments = {
    deploy = { scope = azurerm_resource_group.main.id, role = "Contributor" }
  }
  tags = local.tags
}
