# 14: Cheat sheet

## Project
```bash
make help | check | fmt | docs | lint | test | policy | checkov
make conftest P=envs/aws-dev               # policies on any path
make ai-fix P=path/to/file.tf              # AI-drafted fix (dry run)
./scripts/check.sh                         # all 7 steps, CI order
uv run --group dev pytest -q               # AI fixer tests
```

## Terraform
```bash
terraform fmt -recursive ; terraform validate
terraform init -backend=false | -backend-config=backend.hcl
terraform plan -out tfplan ; terraform apply tfplan ; terraform destroy
terraform test                              # in a module folder
terraform state list | show <addr> ; terraform import <addr> <id>
terraform providers schema -json            # every argument name (when a provider renames one)
TF_PLUGIN_CACHE_DIR=~/.terraform.d/plugin-cache terraform init
```

## OPA / Conftest
```bash
conftest parse --parser hcl2 file.tf
conftest test --parser hcl2 --all-namespaces -p policies file.tf [--output json]
conftest verify -p policies                 # Rego unit tests
opa eval -d policies -i input.json 'data.aws.network.deny'
```

## Scanners
```bash
./scripts/tflint.sh
docker run --rm -v $PWD:/tf bridgecrew/checkov:3.3.29 -d /tf --framework terraform --skip-path tests/fixtures
docker run --rm -v $PWD:/repo -w /repo rhysd/actionlint -oneline
gitleaks detect --source .
```

## Azure CLI
```bash
az login ; az account set -s <sub>
az policy assignment list -o table
az policy state summarize                            # compliance per assignment
az monitor activity-log list --offset 1h -o table
az keyvault list-deleted                             # soft-deleted vaults
az network nsg rule list -g <rg> --nsg-name <nsg> -o table
```

## AWS CLI
```bash
aws sts get-caller-identity
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
aws s3control get-public-access-block --account-id <id>
aws ec2 get-instance-metadata-defaults
aws ec2 get-ebs-encryption-by-default
aws cloudtrail get-trail-status --name lz-dev-trail
aws cloudtrail validate-logs --trail-arn <arn> --start-time 2026-11-01T00:00:00Z
aws guardduty list-detectors ; aws guardduty create-sample-findings --detector-id <id> --finding-types Recon:EC2/PortProbeUnprotectedPort
aws kms get-key-rotation-status --key-id <id>
```

## Rule IDs
`NET` network · `STO` storage · `ENC` encryption · `KV` secrets · `DB` databases · `IAM` identity · `LOG` logging ·
`CMP` compute · `TAG` tags · `GOV` regions. Full list: [docs/rules.md](../rules.md).
