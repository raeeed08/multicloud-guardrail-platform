# Rulebook

Generated from `rulebook/rules.yaml` by `scripts/rulebook.py`. Do not edit by hand.

Each rule is enforced at up to three points: **Prevent** (policy on the Terraform code in the pull request), **Guard** (Azure Policy / AWS SCP in the cloud control plane) and **Detect** (Cloud Copilot scanning the running account).

| ID | Rule | Severity | Prevent (AWS) | Prevent (Azure) | Guard | Detect (Cloud Copilot) |
|---|---|---|---|---|---|---|
| [NET-001](#net-001) | No SSH or RDP open to the internet | critical | `network.rego` | `network.rego` | - | EC2-001, AZ-NSG-001 |
| [NET-002](#net-002) | No database or cluster port open to the internet | critical | `network.rego` | `network.rego` | - | EC2-002, AZ-NSG-002 |
| [NET-003](#net-003) | No rule opening every port to the internet | high | `network.rego` | `network.rego` | - | EC2-003, AZ-NSG-003 |
| [STO-001](#sto-001) | Object storage is never public | critical | `storage.rego` | `storage.rego` | AWS: SCP deny-s3-public-access-changes; AZURE: Azure Policy "Storage account public access should be disallowed" | S3-001, S3-002, S3-003, AZ-STOR-001 |
| [STO-002](#sto-002) | Storage only accepts encrypted connections (TLS 1.2+) | medium | - | `storage.rego` | AZURE: Azure Policy "Secure transfer to storage accounts should be enabled" | S3-004, AZ-STOR-002, AZ-STOR-003 |
| [STO-003](#sto-003) | Storage accounts are not reachable from all networks | medium | - | `storage.rego` | - | AZ-STOR-005 |
| [ENC-001](#enc-001) | Disks and databases are encrypted at rest | high | `encryption.rego` | `compute.rego` | AWS: aws_ebs_encryption_by_default (security baseline module) | EBS-001, EBS-002, RDS-002, AZ-VM-002 |
| [ENC-002](#enc-002) | Encryption keys rotate automatically | medium | `encryption.rego` | `keyvault.rego` | - | KMS-001 |
| [KV-001](#kv-001) | Secret stores are recoverable and private | medium | `encryption.rego` | `keyvault.rego` | - | AZ-KV-001, AZ-KV-002, AZ-KV-003 |
| [DB-001](#db-001) | Databases are never publicly reachable | critical | `database.rego` | `database.rego` | - | RDS-001, AZ-SQL-001 |
| [IAM-001](#iam-001) | No standing administrator access | high | `identity.rego` | `identity.rego` | - | IAM-009 |
| [IAM-002](#iam-002) | No long-lived cloud credentials | high | `identity.rego` | `identity.rego` | - | IAM-005, IAM-006, IAM-007 |
| [LOG-001](#log-001) | Audit logs are complete, tamper-evident and retained | high | `logging.rego` | `logging.rego` | - | CT-001, CT-002, CT-004, AZ-MON-001 |
| [CMP-001](#cmp-001) | Compute instances are hardened against credential theft | medium | `compute.rego` | `compute.rego` | AWS: SCP require-imdsv2 | EC2-005, AZ-VM-001 |
| [TAG-001](#tag-001) | Every resource carries owner, environment and project tags | low | `tagging.rego` | `tagging.rego` | AZURE: Azure Policy "Require a tag on resource groups" | - |
| [GOV-001](#gov-001) | Workloads stay in approved regions | medium | - | - | AWS: SCP deny-unapproved-regions; AZURE: Azure Policy "Allowed locations" | - |

## NET-001

**No SSH or RDP open to the internet** (critical, network)

*Why:* Internet-wide exposure of administration ports (22, 3389) is the most common entry point for brute force and credential stuffing, and the first link of most cloud attack paths.

*Fix:* Restrict the source to a trusted range, or remove the rule and use SSM Session Manager / Azure Bastion.

- Prevent (aws): `policies/aws/network.rego` reads `aws_security_group`, `aws_security_group_rule`, `aws_vpc_security_group_ingress_rule`
- Prevent (azure): `policies/azure/network.rego` reads `azurerm_network_security_group`, `azurerm_network_security_rule`
- Detect: Cloud Copilot EC2-001, AZ-NSG-001
- Frameworks: CIS AWS 5.2, 5.3; CIS AZURE 6.1, 6.2; NIST SC-7, AC-17

## NET-002

**No database or cluster port open to the internet** (critical, network)

*Why:* Databases and caches reachable from anywhere are scanned continuously; one weak password means a data breach.

*Fix:* Allow the port only from the application subnet or security group; use private endpoints.

- Prevent (aws): `policies/aws/network.rego` reads `aws_security_group`, `aws_security_group_rule`, `aws_vpc_security_group_ingress_rule`
- Prevent (azure): `policies/azure/network.rego` reads `azurerm_network_security_group`, `azurerm_network_security_rule`
- Detect: Cloud Copilot EC2-002, AZ-NSG-002
- Frameworks: NIST SC-7

## NET-003

**No rule opening every port to the internet** (high, network)

*Why:* An "allow all" rule silently exposes every service started later on the host.

*Fix:* Replace with explicit ports (for example 443 only).

- Prevent (aws): `policies/aws/network.rego` reads `aws_security_group`, `aws_security_group_rule`, `aws_vpc_security_group_ingress_rule`
- Prevent (azure): `policies/azure/network.rego` reads `azurerm_network_security_group`, `azurerm_network_security_rule`
- Detect: Cloud Copilot EC2-003, AZ-NSG-003
- Frameworks: NIST SC-7

## STO-001

**Object storage is never public** (critical, storage)

*Why:* Public buckets and containers are the classic cloud data leak.

*Fix:* AWS: enable all four Block Public Access settings and never use public ACLs. Azure: set allow_nested_items_to_be_public = false.

- Prevent (aws): `policies/aws/storage.rego` reads `aws_s3_bucket_public_access_block`, `aws_s3_account_public_access_block`, `aws_s3_bucket_acl`
- Prevent (azure): `policies/azure/storage.rego` reads `azurerm_storage_account`
- Guard (aws): SCP deny-s3-public-access-changes
- Guard (azure): Azure Policy "Storage account public access should be disallowed"
- Detect: Cloud Copilot S3-001, S3-002, S3-003, AZ-STOR-001
- Frameworks: CIS AWS 2.1.4; CIS AZURE 3.7; NIST AC-3, AC-21

## STO-002

**Storage only accepts encrypted connections (TLS 1.2+)** (medium, storage)

*Why:* Plain HTTP or old TLS exposes data and keys in transit.

*Fix:* Azure: https_traffic_only_enabled = true and min_tls_version = "TLS1_2". AWS: the secure bucket module adds a bucket policy denying aws:SecureTransport = false.

- Prevent (azure): `policies/azure/storage.rego` reads `azurerm_storage_account`
- Guard (azure): Azure Policy "Secure transfer to storage accounts should be enabled"
- Detect: Cloud Copilot S3-004, AZ-STOR-002, AZ-STOR-003
- Frameworks: CIS AZURE 3.1, 3.15; NIST SC-8

## STO-003

**Storage accounts are not reachable from all networks** (medium, storage)

*Why:* A storage endpoint open to every network only depends on keys and SAS tokens never leaking.

*Fix:* Set public_network_access_enabled = false (private endpoint) or network_rules default_action = "Deny".

- Prevent (azure): `policies/azure/storage.rego` reads `azurerm_storage_account`
- Detect: Cloud Copilot AZ-STOR-005
- Frameworks: CIS AZURE 3.8; NIST SC-7

## ENC-001

**Disks and databases are encrypted at rest** (high, encryption)

*Why:* Unencrypted volumes and snapshots can be copied and read outside your control.

*Fix:* AWS: encrypted = true / storage_encrypted = true. Azure: encryption_at_host_enabled = true on VMs.

- Prevent (aws): `policies/aws/encryption.rego` reads `aws_ebs_volume`, `aws_db_instance`, `aws_rds_cluster`
- Prevent (azure): `policies/azure/compute.rego` reads `azurerm_linux_virtual_machine`, `azurerm_windows_virtual_machine`
- Guard (aws): aws_ebs_encryption_by_default (security baseline module)
- Detect: Cloud Copilot EBS-001, EBS-002, RDS-002, AZ-VM-002
- Frameworks: CIS AWS 2.2.1, 2.3.1; NIST SC-28

## ENC-002

**Encryption keys rotate automatically** (medium, encryption)

*Why:* Rotation limits how much data a single compromised key version protects.

*Fix:* AWS: enable_key_rotation = true. Azure: add a rotation_policy to Key Vault keys.

- Prevent (aws): `policies/aws/encryption.rego` reads `aws_kms_key`
- Prevent (azure): `policies/azure/keyvault.rego` reads `azurerm_key_vault_key`
- Detect: Cloud Copilot KMS-001
- Frameworks: CIS AWS 3.6; NIST SC-12

## KV-001

**Secret stores are recoverable and private** (medium, secrets)

*Why:* Without purge protection one mistake or one attacker deletes every secret for good.

*Fix:* Azure: purge_protection_enabled = true, public_network_access_enabled = false, RBAC authorization. AWS: keep a recovery window on Secrets Manager secrets (never 0).

- Prevent (aws): `policies/aws/encryption.rego` reads `aws_secretsmanager_secret`
- Prevent (azure): `policies/azure/keyvault.rego` reads `azurerm_key_vault`
- Detect: Cloud Copilot AZ-KV-001, AZ-KV-002, AZ-KV-003
- Frameworks: CIS AZURE 8.5, 8.6; NIST CP-9, SC-12

## DB-001

**Databases are never publicly reachable** (critical, database)

*Why:* A public database endpoint turns a password into the only line of defence.

*Fix:* AWS: publicly_accessible = false. Azure: public_network_access_enabled = false and no 0.0.0.0-255.255.255.255 firewall rule; use private endpoints.

- Prevent (aws): `policies/aws/database.rego` reads `aws_db_instance`
- Prevent (azure): `policies/azure/database.rego` reads `azurerm_mssql_server`, `azurerm_mssql_firewall_rule`, `azurerm_postgresql_flexible_server`
- Detect: Cloud Copilot RDS-001, AZ-SQL-001
- Frameworks: CIS AZURE 4.1.2; NIST SC-7

## IAM-001

**No standing administrator access** (high, identity)

*Why:* Permanent admin rights turn any stolen credential into a full account takeover.

*Fix:* Grant least-privilege roles; use just-in-time elevation (AWS IAM Identity Center permission sets with short sessions, Azure PIM) for admin tasks.

- Prevent (aws): `policies/aws/identity.rego` reads `aws_iam_user_policy_attachment`, `aws_iam_role_policy_attachment`, `aws_iam_group_policy_attachment`, `aws_iam_policy_attachment`
- Prevent (azure): `policies/azure/identity.rego` reads `azurerm_role_assignment`
- Detect: Cloud Copilot IAM-009
- Frameworks: CIS AWS 1.16; NIST AC-6

## IAM-002

**No long-lived cloud credentials** (high, identity)

*Why:* Static keys leak through repositories, laptops and CI logs; federated short-lived tokens do not.

*Fix:* Use roles, managed identities and OIDC federation (GitHub Actions) instead of access keys or client secrets.

- Prevent (aws): `policies/aws/identity.rego` reads `aws_iam_access_key`
- Prevent (azure): `policies/azure/identity.rego` reads `azuread_application_password`, `azuread_service_principal_password`
- Detect: Cloud Copilot IAM-005, IAM-006, IAM-007
- Frameworks: CIS AWS 1.14; NIST IA-5

## LOG-001

**Audit logs are complete, tamper-evident and retained** (high, logging)

*Why:* Without a complete audit trail an intrusion can neither be detected nor investigated.

*Fix:* AWS: multi-region CloudTrail with log file validation and KMS. Retain logs at least 90 days (CloudWatch log groups, Log Analytics workspaces).

- Prevent (aws): `policies/aws/logging.rego` reads `aws_cloudtrail`, `aws_cloudwatch_log_group`
- Prevent (azure): `policies/azure/logging.rego` reads `azurerm_log_analytics_workspace`
- Detect: Cloud Copilot CT-001, CT-002, CT-004, AZ-MON-001
- Frameworks: CIS AWS 3.1, 3.2, 3.5; CIS AZURE 5.1.1; NIST AU-2, AU-9, AU-11

## CMP-001

**Compute instances are hardened against credential theft** (medium, compute)

*Why:* IMDSv1 lets an SSRF bug steal the instance role; password SSH invites brute force.

*Fix:* AWS: metadata_options { http_tokens = "required" }. Azure: disable_password_authentication = true.

- Prevent (aws): `policies/aws/compute.rego` reads `aws_instance`, `aws_launch_template`
- Prevent (azure): `policies/azure/compute.rego` reads `azurerm_linux_virtual_machine`
- Guard (aws): SCP require-imdsv2
- Detect: Cloud Copilot EC2-005, AZ-VM-001
- Frameworks: CIS AWS 5.6; NIST AC-3, IA-2

## TAG-001

**Every resource carries owner, environment and project tags** (low, governance)

*Why:* Untagged resources have no owner, no cost centre and no one to call during an incident.

*Fix:* AWS: provider default_tags. Azure: tags on every resource group (required by Azure Policy).

- Prevent (aws): `policies/aws/tagging.rego` reads `provider.aws.default_tags`
- Prevent (azure): `policies/azure/tagging.rego` reads `azurerm_resource_group`
- Guard (azure): Azure Policy "Require a tag on resource groups"
- Frameworks: NIST CM-8

## GOV-001

**Workloads stay in approved regions** (medium, governance)

*Why:* Data residency (GDPR) and a smaller attack surface; unused regions are where crypto-miners hide.

*Fix:* Enforced once by the organisation, not by each project.

- Guard (aws): SCP deny-unapproved-regions
- Guard (azure): Azure Policy "Allowed locations"
- Frameworks: NIST AC-3, SA-9
