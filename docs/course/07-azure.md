# 07: The Azure landing zone (`envs/azure-dev`)

## Hierarchy and identity
Tenant (Entra ID) -> management groups -> **subscriptions** (billing + isolation boundary) -> resource groups ->
resources. Permissions are **Azure RBAC role assignments**: *who* (principal), *what* (role), *where* (scope).
Built-in roles: Owner (everything + grant access), Contributor (everything except access), Reader, plus
data-plane roles such as *Key Vault Secrets User*. IAM-001 forbids standing Owner / User Access Administrator.

## Network (`modules/azure/network`)
- **VNet** 10.10.0.0/16 with three subnets: `snet-app` (workloads), `snet-pe` (private endpoints),
  `snet-mgmt` (reserved).
- **NSG** (network security group) = stateful firewall rules on a subnet or NIC, evaluated by priority (lower
  number first). Default rules allow VNet-internal traffic and deny inbound from the internet; explicit rules
  here: app allows 443 only; pe allows 443 from the app subnet and denies everything else; mgmt denies all.
- `private_endpoint_network_policies = "Enabled"` makes NSGs apply to private endpoints too.

## Private endpoints
A **private endpoint** gives a PaaS service (Storage, Key Vault, SQL) a private IP inside your VNet. With
`public_network_access_enabled = false`, the service is reachable only from the VNet (plus a private DNS zone
such as `privatelink.blob.core.windows.net` so the normal hostname resolves to the private IP).

## Storage (`modules/azure/storage`)
| Setting | Why | Rule |
|---|---|---|
| `allow_nested_items_to_be_public = false` | no anonymous containers | STO-001 |
| `https_traffic_only_enabled`, `min_tls_version = "TLS1_2"` | encryption in transit | STO-002 |
| `public_network_access_enabled = false` + `network_rules { default_action = "Deny" }` | private endpoint only | STO-003 |
| `shared_access_key_enabled = false`, `default_to_oauth_authentication` | no account keys: Entra ID only | IAM-002 |
| `infrastructure_encryption_enabled` | double encryption at rest | ENC |
| versioning, soft delete for blobs and containers | recover from mistakes and ransomware | |
| diagnostic setting (StorageRead/Write/Delete) | audit | LOG |

Because shared keys are off, the provider is configured with `storage_use_azuread = true`, and containers are
created through the management plane (`storage_account_id`), which works without public access.

## Key Vault (`modules/azure/keyvault`)
Secrets, keys and certificates. `rbac_authorization_enabled = true` (RBAC instead of legacy access policies),
`purge_protection_enabled = true` (a deleted vault cannot be purged during the 90-day soft-delete window, even by
an admin: protects against destructive attacks), no public network access, audit logs to Log Analytics. The
module only accepts *Key Vault ...* data-plane roles (validation).

## Monitoring (`modules/azure/monitoring`)
- **Log Analytics workspace**: central log store queried with KQL; 90-day retention (LOG-001) and a daily
  ingestion cap (`daily_quota_gb`, FinOps).
- **Activity Log**: every control-plane operation in the subscription; exported with a subscription-level
  diagnostic setting.
- **Activity log alerts** on operations attackers use: NSG rule write/delete, policy assignment delete, role
  assignment write, Key Vault delete, SQL firewall write, sent to an action group (email).

## Governance (`modules/azure/governance`): the GUARD layer
**Azure Policy** evaluates every create/update request at the Azure Resource Manager API, whatever the tool.
Effects: `Deny` (block), `Audit` (report), `Modify`/`DeployIfNotExists` (remediate). Assignments here:
| Assignment | Built-in definition | Rule |
|---|---|---|
| allowed locations | "Allowed locations" | GOV-001 |
| one per required tag | "Require a tag on resource groups" | TAG-001 |
| no public storage | "Storage account public access should be disallowed" | STO-001 |
| secure transfer | "Secure transfer to storage accounts should be enabled" | STO-002 |

`enforce = false` / `effect = "Audit"` gives a safe rollout: observe violations first, then deny.
Definitions are looked up by display name (`data "azurerm_policy_definition"`) instead of hard-coded GUIDs.

**Microsoft Defender for Cloud**: CSPM + workload protection. Plans (VirtualMachines, StorageAccounts,
KeyVaults, Arm...) are paid, hence an empty default list.

## Interview questions
1. **NSG vs Azure Firewall?** NSG: distributed L3/L4 allow/deny per subnet/NIC, free. Azure Firewall: central
   managed L3-L7 firewall with FQDN rules and threat intelligence, paid.
2. **Private endpoint vs service endpoint?** Private endpoint: private IP for one resource in your VNet, can
   disable public access completely. Service endpoint: optimised route from a subnet to the service's public
   endpoint, still a public IP.
3. **Azure Policy vs RBAC?** RBAC: *who* can act. Policy: *what* is allowed, regardless of who.
4. **Why purge protection?** Without it, an attacker or a mistake can permanently destroy all secrets and keys.
5. **Managed identity?** An identity for an Azure resource whose credentials Azure rotates; no secret to store.
