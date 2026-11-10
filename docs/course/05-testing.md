# 05: Testing infrastructure code

Three kinds of tests, from fastest to most realistic.

## 1. Rego unit tests (`policies/lib/net_test.rego`)
```rego
test_port_specs if {
    net.spec_covers("20-30", 22)
    not net.spec_covers("80", 22)
}
```
`conftest verify -p policies` runs every `test_*` rule. Use them for helpers with tricky edge cases (ranges,
protocols, unknown values).

## 2. Fixtures with exact expectations (`tests/fixtures`, `scripts/test_policies.py`)
Each fixture lists the rules it tests and marks every insecure case:
```hcl
# rules: NET-001, NET-002, NET-003
# expect: NET-001
# expect: NET-002  (the range also contains MySQL 3306)
ingress { from_port = 3000  to_port = 4000 ... cidr_blocks = ["0.0.0.0/0"] }
```
The script runs Conftest on every fixture and requires **caught == expected** for each listed rule:
- fewer caught = the policy **misses** a misconfiguration (false negative);
- more caught = the policy flags a **safe** case (false positive).

It also checks that every rule in the rulebook with a `prevent` entry has a policy file that mentions it and at
least one fixture that proves it. True story: when the fixtures were first written, the runner reported
`NET-002 expected 2, caught 3`. The policy was right: the range 3000-4000 also contains MySQL's port 3306. The
fixture was corrected. This is exactly why expectations are explicit.

## 3. `terraform test` with mock providers (`modules/*/*/tests/*.tftest.hcl`)
Native Terraform testing (1.6+), mock providers (1.7+):
```hcl
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }            # resources that validate JSON need valid JSON
  }
}

variables { name = "lz-test-data-111122223333" }

run "locked_down_by_default" {
  command = plan
  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "STO-001: all four Block Public Access settings must be on."
  }
}

run "rejects_invalid_name" {
  command = plan
  variables { name = "Invalid_Bucket" }
  expect_failures = [var.name]              # the validation MUST fail
}
```
- `mock_provider` replaces the real provider: no credentials, no cost, no network. Computed attributes get fake
  values; data sources can be given defaults.
- `command = plan` evaluates the module's logic; assertions check configured values.
- `expect_failures` turns validations and preconditions into tests (a guardrail that cannot fail is useless).

**Lessons from building it** (good interview material):
- Mocked `aws_iam_policy_document.json` is a random string, and `aws_kms_key` validates JSON: provide a default.
- `aws_default_security_group.ingress` is *computed* when not set, so it is unknown at plan time. The module now
  sets `ingress = []` and `egress = []` explicitly: clearer intent and testable.

**Limits**: mocks prove the module's logic, not that AWS/Azure accept the values (a wrong SKU name passes). That
gap is covered by tflint (provider-aware) and, ultimately, by a real deployment (chapter 12).

## Commands
```bash
make policy                                   # fixtures + Rego unit tests + coverage
terraform -chdir=modules/aws/network init -backend=false && terraform -chdir=modules/aws/network test
make test                                     # every module + validate every env
```

## Interview questions
1. **How do you test Terraform?** Static (fmt, validate, tflint, Checkov, policies), unit-like tests with
   `terraform test` and mock providers, integration tests in a sandbox account (Terratest or `terraform test` with
   `command = apply`), and runtime verification.
2. **How do you test a policy?** Unit tests for helpers, plus insecure and safe fixtures with exact expected counts.
3. **What does a mock provider not prove?** That the cloud accepts the request (quotas, names, regions,
   permissions).
