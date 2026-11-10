# 03: Repository tour

```
rulebook/rules.yaml          16 rules: the single source of truth
docs/rules.md                generated from the rulebook (scripts/rulebook.py)
policies/
  lib/core.rego              shared helpers: resources(), unknown values, msg()
  lib/net.rego               ports, ranges, internet sources (+ net_test.rego unit tests)
  aws/*.rego                 network, storage, encryption, database, identity, logging, compute, tagging
  azure/*.rego               network, storage, keyvault, database, identity, logging, compute, tagging
tests/fixtures/aws|azure     insecure and safe Terraform cases, "# expect: RULE-ID"
modules/aws/                 network, kms, s3-secure-bucket, cloudtrail, security-baseline, github-oidc,
                             org-guardrails (each with tests/*.tftest.hcl)
modules/azure/               network, storage, keyvault, monitoring, governance, github-oidc
envs/azure-dev               Azure landing zone root
envs/aws-dev                 AWS workload account root
envs/aws-org                 SCPs, applied from the Organizations management account
scripts/check.sh             every check, CI order
scripts/test_policies.py     caught == expected, rulebook coverage
scripts/tf_test.sh           validate envs + terraform test modules
scripts/tflint.sh            tflint on modules and envs
tools/ai_fix.py              AI fix loop (+ test_ai_fix.py)
.github/workflows/           guardrails.yml (PR checks), deploy.yml (OIDC deploy)
```

## Follow one rule end to end: NET-001 (no SSH/RDP from the internet)
1. **Rulebook**: `rulebook/rules.yaml` defines NET-001, why, how to fix, the resource types, the Cloud Copilot IDs
   `EC2-001` and `AZ-NSG-001`.
2. **Policy**: `policies/aws/network.rego` normalises the three ways to write an AWS inbound rule into
   "exposures", then reports `NET-001 [critical]: ...` when port 22 or 3389 is open to `0.0.0.0/0` or `::/0`.
   `policies/azure/network.rego` does the same for NSG rules.
3. **Proof**: `tests/fixtures/aws/network.tf` contains SSH open to the world (`# expect: NET-001`), SSH from
   10.0.0.0/8 (safe), UDP 22 (safe), a 0-1024 range (`# expect: NET-001`)... `scripts/test_policies.py`
   fails if the counts differ.
4. **Self-check**: the real modules must have zero violations (`check.sh` step 6).
5. **Module design**: the Azure network module only opens 443 on the app subnet; the AWS VPC locks the default SG.
6. **Runtime**: if someone opens SSH in the console anyway, Cloud Copilot raises `EC2-001` / `AZ-NSG-001`.
7. **Fix**: `tools/ai_fix.py` can draft the change; CI re-checks it; a human merges.

## How the checks chain (scripts/check.sh)
```
1 terraform fmt -check          formatting
2 rulebook.py --check           rulebook valid, docs/rules.md up to date
3 tflint.sh                     provider-aware lint
4 tf_test.sh                    validate envs, terraform test modules (mocks)
5 test_policies.py              Rego unit tests + fixtures caught exactly + coverage
6 conftest on modules + envs    the landing zone passes its own rules
7 checkov                       independent scanner
```
