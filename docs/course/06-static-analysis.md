# 06: Static analysis: terraform validate, tflint, Checkov, gitleaks

| Tool | Catches | Example |
|---|---|---|
| `terraform fmt` | formatting | misaligned `=` |
| `terraform validate` | syntax, types, unknown arguments | `enable_rbac_authorizationn` |
| **tflint** + rulesets | provider-specific mistakes, deprecated syntax, unused declarations | invalid instance type, unused `data "aws_partition"` (found here) |
| **Checkov** | security misconfigurations (~1,000 checks, CIS-aligned) | S3 without versioning, KMS without rotation |
| **Conftest** | *our* rulebook | NET-001 ... TAG-001 |
| **gitleaks** | secrets in Git history | an AWS key in a commit |
| **actionlint** | GitHub Actions mistakes, shellcheck in `run:` steps | quoting bug in a summary step (found here) |

## tflint
```bash
./scripts/tflint.sh               # every module and env, AWS + azurerm rulesets (.tflint.hcl)
```
`.tflint.hcl` enables the `terraform` recommended preset and pins the AWS and azurerm ruleset versions. Fixtures
are excluded on purpose: they are incomplete snippets.

## Checkov and how to triage
```bash
make checkov
```
Result here: **282 passed, 0 failed, 22 skipped**. Every finding was handled in one of three ways:
1. **Fix it** when it is a real gap.
2. **Skip with a reason, inline, where it applies** (never a blanket ignore list):
   ```hcl
   data "aws_iam_policy_document" "key" {
     #checkov:skip=CKV_AWS_109:Key policy. Resource "*" means this key only; this is the AWS default key policy.
   ```
   False positives here: KMS key policies (`Resource "*"` in a key policy means "this key"), blob logging already
   exported by a diagnostic setting.
3. **Accept a documented trade-off**: cross-region replication (doubles cost), 1-year retention in CloudWatch
   (S3 keeps the full history), customer-managed keys for storage (next step), SNS for CloudTrail (alarms used).

In CI, Checkov results are uploaded as **SARIF** to the GitHub *Security* tab (code scanning), where findings
appear on the lines of the pull request.

## Interview questions
1. **How do you handle a security scanner's false positives?** Verify, then suppress narrowly (inline, per resource)
   with a written reason and an owner; never disable the check globally.
2. **What is SARIF?** A standard JSON format for static analysis results, understood by GitHub code scanning.
3. **Why tflint if you have validate?** Validate checks the schema; tflint knows provider semantics (valid values,
   deprecations) and best practices.
