# 04: Policy as code with OPA, Rego and Conftest

## The tools
- **OPA (Open Policy Agent)**: a general policy engine, a CNCF graduated project. It evaluates rules written in
  **Rego** against any JSON input. Used for Kubernetes admission (Gatekeeper), APIs, Terraform, CI.
- **Conftest**: a CLI around OPA for configuration files. It parses Terraform (HCL2), YAML, Dockerfiles... into
  JSON, and runs every `deny` rule. Exit code 1 if any `deny` produces a message.

```bash
conftest parse --parser hcl2 main.tf                         # see the JSON your policy will receive
conftest test --parser hcl2 --all-namespaces -p policies main.tf
conftest verify -p policies                                  # run *_test.rego unit tests
```

## What the input looks like
```json
{ "resource": { "aws_security_group": { "web": [ { "ingress": [ { "from_port": 22, "to_port": 22,
    "protocol": "tcp", "cidr_blocks": ["0.0.0.0/0"] } ], "tags": "${var.tags}" } ] } } }
```
Resources are `type -> name -> [body]`, nested blocks are lists, and **references to variables or other resources
are strings like `"${var.tags}"`**: the code does not know their value.

## Rego in ten minutes
```rego
package aws.database                 # namespace; conftest runs all of them with --all-namespaces
import rego.v1                       # modern syntax (if / contains / in)
import data.lib.core                 # our helpers

# A partial set rule: every true body adds one message to "deny".
deny contains msg if {
    some [name, body] in core.resources("aws_db_instance")   # iterate
    object.get(body, "publicly_accessible", false) == true   # condition with a default
    msg := sprintf("DB-001 [critical]: aws_db_instance.%s is publicly accessible.", [name])
}
```
Key ideas:
- A rule body is a set of conditions that must **all** be true (AND). Several bodies for the same rule = OR.
- `some x in coll` iterates; `object.get(obj, key, default)` reads safely.
- If an expression is undefined (missing field), the body just does not match: no crash, no message.
- `not f(x)` is true when `f(x)` is undefined or false.
- Functions: `f(x) := value if { ... }` and boolean `f(x) if { ... }`.

## Our conventions
- Message format `RULE-ID [severity]: text` (`core.msg`), so tools can count and route by rule.
- **Unknown values get the benefit of the doubt**: `core.not_enabled(body, "encrypted")` is true only if the value is
  missing (provider default false) or explicitly false, not if it is `"${var.x}"`. That avoids false positives;
  the deployed value is checked at runtime by Cloud Copilot. This trade-off is stated in the rulebook header.
- Provider defaults are encoded honestly: `allow_nested_items_to_be_public` defaults to **true** in azurerm 4.x, so a
  missing value fails STO-001; `min_tls_version` defaults to TLS1_2, so a missing value passes STO-002.
- **Normalisation** (network policies): three ways to write an AWS inbound rule (`aws_security_group` inline
  `ingress`, `aws_security_group_rule`, `aws_vpc_security_group_ingress_rule`) become one "exposure" record, so
  NET-001/002/003 are written once. A rule that opens all ports is reported as NET-003 only, not three times.

## Write a new rule end to end (exercise: STO-004 "no S3 bucket without versioning")
1. Add it to `rulebook/rules.yaml` (id, why, fix_hint, prevent.aws.policy, resources, detect).
2. Add a `deny` in `policies/aws/storage.rego`.
3. Add fixtures to `tests/fixtures/aws/storage.tf`: insecure cases with `# expect: STO-004`, safe cases, and
   `STO-004` in the `# rules:` header.
4. `make policy` until caught == expected; `make docs`; `make check`.

## Limits (say them in interviews)
- HCL policies cannot see computed values, module internals passed through variables, or data sources.
  Next step: policies on the **plan JSON** (`terraform show -json tfplan`), which has resolved values.
- Policies do not replace the cloud-side guard: someone can still click in the console. Hence SCPs, Azure Policy
  and runtime detection.

## Interview questions
1. **What is OPA / Rego?** A general-purpose policy engine and its declarative language; input is JSON, output is
   decisions (here: deny messages).
2. **Conftest vs Checkov?** Conftest runs *your* policies on any config; Checkov ships ~1,000 maintained checks for
   common frameworks. Use both: generic coverage plus organisation-specific rules.
3. **How do you avoid false positives?** Encode provider defaults correctly, treat unknown values carefully,
   prove each policy on safe cases that must pass.
4. **HCL vs plan JSON for policies?** HCL: fast, no credentials, but unresolved values. Plan: resolved values,
   needs credentials and a plan step.
