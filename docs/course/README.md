# Course: the Multi-Cloud Guardrail Platform, from zero to interview-ready

This course explains every concept and tool used in this repository: what it is, why it exists, how it is used
here, the commands that matter and the questions interviewers ask about it. Read it in order the first time;
afterwards use [14-cheatsheet.md](14-cheatsheet.md).

| # | Chapter | You will be able to... |
|---|---|---|
| 01 | [The big picture](01-big-picture.md) | explain landing zones, guardrails and prevent / guard / detect |
| 02 | [Terraform from zero](02-terraform.md) | read and write every Terraform construct used here |
| 03 | [Repository tour](03-repository-tour.md) | find anything and follow a rule from YAML to cloud |
| 04 | [Policy as code with OPA/Rego](04-policy-as-code.md) | read our policies and write a new rule end to end |
| 05 | [Testing infrastructure code](05-testing.md) | explain fixtures, Rego unit tests and `terraform test` with mocks |
| 06 | [Static analysis: tflint, Checkov](06-static-analysis.md) | triage findings and justify a skip |
| 07 | [The Azure landing zone](07-azure.md) | explain NSGs, private endpoints, Key Vault, Azure Policy, Defender |
| 08 | [The AWS landing zone](08-aws.md) | explain VPC, KMS, S3, CloudTrail, GuardDuty, Organizations and SCPs |
| 09 | [Secretless CI/CD with OIDC](09-oidc.md) | set up GitHub -> AWS / Azure federation and explain why it is safer |
| 10 | [The CI/CD pipelines](10-cicd.md) | walk through every job of guardrails.yml and deploy.yml |
| 11 | [The AI fix loop](11-ai-fix.md) | explain how an LLM is used safely on infrastructure code |
| 12 | [Hands-on lab](12-lab.md) | deploy, break, watch each layer catch it, and clean up |
| 13 | [Interview preparation](13-interview.md) | pitch the project and answer the classic questions |
| 14 | [Cheat sheet](14-cheatsheet.md) | find any command in seconds |

## The 30-second pitch

"I built a secure landing zone for AWS and Azure in Terraform where one rulebook of 16 security rules is enforced
three times: in the pull request with custom OPA/Rego policies plus Checkov, at the cloud API with Azure Policy and
AWS SCPs, and at runtime by my scanner Cloud Copilot, which uses the same rule IDs. Every policy is proven by test
cases that must be caught exactly, every module has Terraform tests, CI uses OIDC so no cloud secret exists, and
when a policy fails an LLM drafts the fix, which is only accepted if it passes the same policies and a human
approves the pull request."

## How it relates to Cloud Copilot

| | Guardrail Platform (this repo) | Cloud Copilot |
|---|---|---|
| Question answered | "Can this change make us insecure?" | "Is what is running secure right now?" |
| Input | Terraform code, pull requests | Live AWS / Azure APIs |
| When | Before and during deployment | After deployment, continuously |
| Shared | Rule IDs (`detect.copilot` in the rulebook) | Rule IDs, remediation, CIS / NIST mapping |

Together they form the "shift left + shield right" story companies call **DevSecOps for the cloud**.
