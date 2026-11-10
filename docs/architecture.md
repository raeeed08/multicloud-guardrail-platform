# Architecture

## Three enforcement points, one rulebook

```mermaid
flowchart TB
    subgraph Dev[Developer]
        PRC[Terraform change<br/>pull request]
    end
    subgraph CI[GitHub Actions - PREVENT]
        F[fmt + rulebook + tflint] --> T[validate + terraform test]
        T --> CP[Conftest: Rego policies]
        CP --> CK[Checkov -> Security tab]
        CK --> GL[gitleaks]
    end
    subgraph Deploy[deploy.yml]
        PL[plan via OIDC] --> AP{Reviewer approves<br/>dev-apply environment}
        AP --> APPLY[apply the reviewed plan]
    end
    subgraph Cloud[Cloud control plane - GUARD]
        AZP[Azure Policy<br/>locations, tags, storage]
        SCP[AWS SCPs<br/>IMDSv2, encryption, regions,<br/>protect logging]
    end
    subgraph Runtime[Running accounts - DETECT]
        CC[Cloud Copilot scans<br/>same rule IDs]
    end
    RB[(rulebook/rules.yaml)] -.-> CP
    RB -.-> AZP
    RB -.-> SCP
    RB -.-> CC
    PRC --> CI --> Deploy --> Cloud
    Cloud --> Runtime
    CP -- violation --> AIF[tools/ai_fix.py] -- draft PR --> PRC
    CC -- drift found --> PRC
```

| Layer | Sees | Cannot see | Implemented by |
|---|---|---|---|
| Prevent | Intent, before anything exists | Values only known at deploy time; console changes | Conftest/Rego, Checkov, tflint, `terraform test` |
| Guard | Every API call, whatever the tool | Why the change was made; already-existing resources (audit only) | Azure Policy assignments, AWS SCPs, account baselines |
| Detect | The real, current state | Changes before they happen | Cloud Copilot (runtime scanner) |

## Azure landing zone (`envs/azure-dev`)

```mermaid
flowchart LR
    subgraph Sub[Subscription]
        GOV[Azure Policy assignments<br/>GOV-001 TAG-001 STO-001 STO-002<br/>+ Defender plans]
        ACT[Activity Log] --> LAW
        subgraph RG[rg-lz-dev]
            LAW[Log Analytics 90 days]
            ALERT[Activity log alerts<br/>NSG, policy, roles, Key Vault, SQL]
            subgraph VNET[VNet 10.10.0.0/16]
                APP[snet-app<br/>NSG: 443 only]
                PE[snet-pe<br/>NSG: app -> 443, deny rest]
                MGMT[snet-mgmt<br/>NSG: deny all]
            end
            KV[Key Vault<br/>RBAC, purge protection,<br/>no public access]
            ST[Storage<br/>no public, no shared keys,<br/>TLS 1.2, soft delete]
            ID[Managed identity<br/>GitHub OIDC]
        end
    end
    PE --- KV
    PE --- ST
    KV -. audit logs .-> LAW
    ST -. blob logs .-> LAW
    LAW --> ALERT
```

## AWS landing zone (`envs/aws-dev`, `envs/aws-org`)

```mermaid
flowchart LR
    subgraph Org[AWS Organizations - envs/aws-org]
        SCPS[SCPs: protect-security,<br/>data-protection, regions]
    end
    subgraph Acc[Workload account - envs/aws-dev]
        BASE[Baseline: S3 public block, EBS encryption,<br/>snapshot block, IMDSv2 default,<br/>GuardDuty, Access Analyzer, password policy]
        subgraph VPC[VPC 10.20.0.0/16, 2 AZs]
            PUB[Public subnets<br/>no auto public IP]
            PRIV[Private subnets]
            DSG[Default SG: no rules]
            VPCE[S3 gateway endpoint]
        end
        FL[Flow logs -> CloudWatch 90d, KMS]
        CT[CloudTrail multi-region<br/>validation + KMS] --> S3L[(Log bucket<br/>TLS-only, BPA, versioned)]
        CT --> CWL[CloudWatch Logs] --> ALM[Tampering alarm]
        KMS[KMS keys, rotation] --> S3D[(Data bucket)]
        OIDC[IAM role for GitHub OIDC<br/>repo + environment pinned]
    end
    SCPS -. caps every identity .-> Acc
    VPC --> FL
```

## Why some choices were made

- **Rego reads HCL, not the plan.** It runs on every pull request in seconds without cloud credentials. The price:
  values coming from variables are unknown. Policies give them the benefit of the doubt (no false positive) and
  the runtime layer catches the deployed value. Policies on `terraform show -json` plans are the next step once
  a plan exists in CI.
- **Conftest + custom Rego and Checkov.** Checkov brings ~1,000 generic checks; the custom policies encode *our*
  rulebook with *our* rule IDs and messages, which is what ties the three layers together.
- **Mock providers for tests.** Real assertions on the plan of every module without credentials or cost. The
  trade-off is documented in the course: mocks do not prove that AWS/Azure accept the values; a live lab does.
- **OIDC everywhere.** No cloud secret exists in GitHub. Trust is pinned to `repo:<owner>/<repo>:environment:<env>`
  so a fork, another branch or another workflow cannot assume the role.
- **Cheap by default.** NAT gateways, Defender plans, Security Hub and geo-redundant storage are opt-in variables.
