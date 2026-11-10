# 12: Hands-on lab

## Part A: no cloud account needed (30 min)
```bash
make check                                     # all seven steps green
make policy                                    # read the table: expected = caught for every rule
```
1. **Break a policy on purpose**: in `policies/aws/network.rego`, change `admin_ports` to `{3389}` only. Run
   `make policy`: NET-001 is now *missed* in the fixtures. Revert.
2. **Create a violation**: add to `envs/aws-dev/main.tf`
   ```hcl
   resource "aws_security_group" "debug" {
     name   = "debug"
     vpc_id = module.network.vpc_id
   }

   resource "aws_security_group_rule" "debug_ssh" {
     type              = "ingress"
     from_port         = 22
     to_port           = 22
     protocol          = "tcp"
     cidr_blocks       = ["0.0.0.0/0"]
     security_group_id = aws_security_group.debug.id
   }
   ```
   Run `make conftest P=envs/aws-dev/main.tf` and `make checkov`. Both flag it.
3. **Let the AI fix it** (needs an API key): `make ai-fix P=envs/aws-dev/main.tf`. Read the diff. Revert.
4. **Break a module test**: set `map_public_ip_on_launch = true` in `modules/aws/network/main.tf`, run
   `terraform -chdir=modules/aws/network test`. Revert.

## Part B: deploy Azure (1 h, a few cents if destroyed the same day)
Prerequisites: an Azure subscription, `az login`.
```bash
cd envs/azure-dev
cp terraform.tfvars.example terraform.tfvars        # set subscription_id and security_email
terraform init -backend=false                       # local state for a lab only
terraform plan                                      # read it
terraform apply
```
Then watch each layer:
1. **Guard**: try to create a storage account in `eastus` from the portal: Azure Policy *Allowed locations*
   denies it (GOV-001). Try a resource group without tags: denied (TAG-001).
2. **Alerts**: add an NSG rule in the portal: an activity log alert email arrives.
3. **Detect**: connect the subscription to Cloud Copilot (read-only service principal) and scan.
4. **Clean up**: `terraform destroy`. The Key Vault stays soft-deleted for 90 days (purge protection): that is the
   control working, and it costs nothing.

## Part C: deploy AWS (1 h)
Prerequisites: an AWS account (not the organisation management account), an admin profile.
```bash
cd envs/aws-dev
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false && terraform plan && terraform apply
```
Then:
1. Launch an instance with IMDSv1 in the console: it gets IMDSv2 anyway (account default).
2. Try to make the data bucket public: the account and bucket public access blocks refuse.
3. `aws cloudtrail stop-logging --name lz-dev-trail`: the tampering alarm fires within 5 minutes. Start it again.
4. GuardDuty findings page: generate sample findings (Settings -> Sample findings).
5. `terraform destroy`. KMS keys enter a 30-day pending-deletion window (no charge).

SCPs (`envs/aws-org`) need an AWS Organization: apply them to a sandbox OU and test with an account inside it.

## Cost notes
Defaults avoid NAT, Defender plans, Security Hub and geo-redundant storage. GuardDuty (30-day free trial), log
ingestion and KMS keys (about 1 USD/month each) are the main costs. Set a budget alert before starting.
