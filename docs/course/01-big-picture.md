# 01: The big picture

## The problem
In the cloud, the provider secures the infrastructure (data centres, hypervisors, hardware): that is the
**shared responsibility model**. Everything *you* configure is yours: who can log in, which ports are open, whether
a bucket is public, whether data is encrypted. Industry reports agree that most cloud incidents come from
**misconfiguration**, not from exotic exploits: a storage container left public, SSH open to the internet, an
admin account without MFA, an access key committed to Git.

Misconfigurations happen because cloud platforms are huge, defaults are not always safe, and many people change
infrastructure under time pressure. You cannot rely on "being careful"; you need **guardrails**.

## Landing zone
A **landing zone** is the pre-configured, secure foundation that workloads "land" on: accounts or subscriptions,
networking, identity, logging, security services and policies, created the same way every time, as code.

- AWS has *Control Tower* and the *Landing Zone Accelerator*; Azure has the *Cloud Adoption Framework landing
  zones*. Companies often build their own in Terraform, which is what this project does at a smaller scale.
- Typical building blocks (and where they are here):

| Building block | AWS | Azure |
|---|---|---|
| Isolation unit | Account (+ Organizations OUs) | Subscription (+ management groups) |
| Network | VPC, subnets, security groups | VNet, subnets, NSGs |
| Audit | CloudTrail | Activity Log -> Log Analytics |
| Threat detection | GuardDuty | Defender for Cloud |
| Keys and secrets | KMS, Secrets Manager | Key Vault |
| Organisation rules | SCPs | Azure Policy |
| CI identity | IAM role + OIDC | Managed identity + federated credential |

## Guardrails: preventive, detective, corrective
- **Preventive**: stop the mistake before it exists (a CI policy that fails the pull request, an SCP that denies
  the API call).
- **Detective**: notice the mistake after it exists (a scanner, GuardDuty, an Azure Policy in audit mode).
- **Corrective**: fix it (a pull request with the remediation, an auto-remediation function).

This project covers all three, around **one rulebook**:

```
                     rulebook/rules.yaml  (NET-001 ... GOV-001)
                    /            |                  \
   PREVENT (pull request)   GUARD (cloud API)     DETECT (runtime)
   Rego + Checkov + tflint  Azure Policy + SCPs   Cloud Copilot
            \                                        /
             '--> violation --> AI drafts fix --> draft PR --> human review
```

Why three layers? Each has a blind spot:

| Layer | Blind spot | Covered by |
|---|---|---|
| Prevent (code) | Console changes; values only known at deploy time | Guard + Detect |
| Guard (API) | Resources created before the policy; context | Detect |
| Detect (runtime) | Damage is possible between creation and scan | Prevent + Guard |

This idea is called **defence in depth**, and "shift left" (prevent early) + "shield right" (detect in
production).

## Policy as code
Writing rules as code (Rego, Azure Policy JSON, SCP JSON) instead of in a wiki gives you version control, review,
tests and automatic enforcement. A rule that is not executed is a wish.

## The rulebook
`rulebook/rules.yaml` is the single source of truth. Each rule has:
- an **ID** (`NET-001`) used everywhere: in policy messages, Azure Policy assignment names, Cloud Copilot findings;
- **why** it matters and **how to fix** it (also fed to the AI fixer);
- where it is **prevented** (Rego file + resource types), **guarded** (Azure Policy / SCP) and **detected**
  (Cloud Copilot rule IDs);
- **frameworks** (CIS benchmarks, NIST 800-53).

`docs/rules.md` is generated from it, so the documentation can never drift from the rules.

## Interview questions
1. **What is a landing zone?** A secure, repeatable foundation (accounts/subscriptions, network, identity,
   logging, security services, policies) created as code before any workload is deployed.
2. **Preventive vs detective controls?** Preventive stops a change (CI policy, SCP deny); detective reports
   after the fact (scanner, GuardDuty). You need both because each has blind spots.
3. **What is "shift left"?** Moving checks earlier in the lifecycle (to the pull request), where fixing is cheapest.
4. **Why one rulebook?** The same ID means the same thing in CI, at the API and at runtime: fewer duplicates,
   consistent reporting, one place to change a rule.
