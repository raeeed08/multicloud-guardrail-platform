# 13: Interview preparation

## Pitch
**30 seconds**: see [README](README.md). **2 minutes**:
1. *Problem*: most cloud incidents are misconfigurations; teams control them at one point only.
2. *Solution*: a Terraform landing zone for AWS and Azure with one rulebook enforced in the pull request (Rego +
   Checkov), at the API (Azure Policy, SCPs) and at runtime (Cloud Copilot).
3. *Proof*: every policy is tested with insecure and safe cases that must be caught exactly; 13 modules have
   Terraform tests with mock providers; the landing zone passes its own rules; Checkov 282 passed, 0 failed.
4. *Delivery*: GitHub Actions with OIDC on both clouds (no secrets), reviewed plans, approval gates, SARIF,
   gitleaks, Dependabot.
5. *AI*: an LLM drafts fixes, accepted only if the same policies pass, opened as a draft PR for a human.
6. *Honest limit*: verified statically and with mocks; a live deployment is the next step.

## True STAR stories from building it
- **The fixture that was wrong, not the policy.** S: my new test runner reported NET-002 "expected 2, caught 3".
  T: decide whether the policy or the test was wrong. A: traced the extra hit to a 3000-4000 port range: it
  contains MySQL's 3306. R: fixed the fixture, kept the policy. Lesson: explicit expectations turn a vague
  "looks fine" into a precise disagreement you can investigate.
- **Mocks that were too random.** `terraform test` failed with "policy contains an invalid JSON": the mock
  provider returns random strings for policy documents and KMS validates JSON. Added mock defaults. Lesson: know
  what a mock fakes.
- **Testable intent.** Asserting "the default security group has no rules" failed because the attribute is
  computed when unset. Setting `ingress = []` explicitly made the intent visible in code *and* testable.
- **Triage, not suppression.** Checkov flagged 20 items. I fixed none blindly and suppressed none globally: each
  was either a false positive (KMS key policies) or a cost trade-off, documented inline next to the resource.
- **The KMS condition that would have failed in production.** CloudWatch Logs authorises through an encryption
  context, not `aws:SourceAccount`; the key policy now uses the right condition per service. Lesson: read the
  service's documentation for key policies, not a generic template.
- **Working with a bad network.** Provider downloads kept failing; I used a filesystem mirror
  (`provider_installation`) so tests ran offline, and a cache in CI.

## Questions with model answers
**Landing zones and governance**
1. *What goes in a landing zone?* Account/subscription structure, identity, network, logging, security services,
   policies, CI identity, all as code.
2. *SCP vs Azure Policy?* SCP caps API permissions for accounts in an OU (IAM-like deny); Azure Policy evaluates
   resource properties (deny/audit/modify) at the Resource Manager API.
3. *How do you roll out a deny policy without breaking teams?* Audit mode first, fix or exempt, communicate, then
   deny; break-glass exemption; sandbox OU first.
4. *Preventive vs detective?* Prevent in CI and at the API, detect at runtime; you need both.

**Terraform**
5. *State: what, where, why locking?* Mapping to real resources; remote, encrypted, locked to prevent concurrent
   applies corrupting it.
6. *How do you test modules?* fmt/validate/tflint/Checkov, `terraform test` with mocks for logic, sandbox apply
   for integration, policies for rules.
7. *How do you structure environments?* Reusable modules + one root per environment with its own state.
8. *Drift?* Detect with plan and runtime scanners; fix in code.

**Policy as code**
9. *What is OPA/Rego?* Policy engine and language over JSON input; Conftest applies it to config files.
10. *Why custom policies if Checkov exists?* Organisation-specific rules and IDs that link prevention, guardrails
    and detection.
11. *Limits of HCL policies?* Unresolved variables and computed values; plan-JSON policies and runtime checks
    complement them.

**Security**
12. *Explain IMDSv2.* Session token via PUT before reading metadata; blocks most SSRF credential theft.
13. *How do you secure an S3 bucket / a storage account?* Block public access, no ACLs / no public containers,
    TLS-only, encryption with KMS, versioning, private network access, logging.
14. *Key Vault purge protection?* Prevents permanent deletion during the retention window, even by admins.
15. *OIDC for CI?* Short-lived tokens, trust pinned to repo + environment, no stored secrets.
16. *Least privilege for CI?* Scoped roles (never admin), permissions boundary, environment approvals.

**AI**
17. *How do you use an LLM safely here?* Untrusted output, deterministic validation, no credentials, draft PR,
    human review.

## Questions to ask the interviewer
- How do you enforce cloud guardrails today: in CI, with SCPs / Azure Policy, or after the fact?
- How are exceptions to a security policy requested, approved and expired?
- Do your pipelines use OIDC or stored cloud credentials?

## Daily drill
Say the pitch aloud, explain one module without notes, answer five questions above, run one command from the
cheat sheet you have not used yet.
