# 09: Secretless CI/CD with OIDC federation

## The problem with keys in CI
Storing `AWS_SECRET_ACCESS_KEY` or an Azure client secret in GitHub means a long-lived credential that can leak
through logs, forks, compromised actions or a stolen token, and that someone must rotate. IAM-002 forbids it.

## How OIDC federation works
```
GitHub Actions job                  Cloud identity provider              Cloud
   | 1. request OIDC token (JWT)        |                                  |
   |    sub = repo:owner/repo:environment:dev, aud = sts.amazonaws.com    |
   | 2. present the JWT --------------> AWS STS AssumeRoleWithWebIdentity |
   |                                    / Entra ID token exchange         |
   |                                    3. verify signature (GitHub's     |
   |                                       public keys), issuer, aud, sub |
   | <------------- 4. temporary credentials (1 hour) ------------------- |
   | 5. terraform plan / apply --------------------------------------------> |
```
Nothing secret is stored. The workflow needs `permissions: id-token: write`.

## The trust is the security
The **subject** (`sub` claim) says who is asking. Pin it exactly:
- `repo:owner/repo:environment:dev`: only jobs running in the GitHub *environment* `dev` (which can require
  reviewers and restrict branches);
- never `repo:owner/*` or `repo:owner/repo:*` (any branch, any pull request from a collaborator).
Both modules enforce this with validations (`modules/aws/github-oidc`: exact `StringEquals`, no `*`;
`modules/azure/github-oidc`: no trailing wildcard).

## AWS side (`modules/aws/github-oidc`)
- `aws_iam_openid_connect_provider` for `https://token.actions.githubusercontent.com`, audience
  `sts.amazonaws.com` (one per account).
- `aws_iam_role` whose trust policy allows `sts:AssumeRoleWithWebIdentity` with conditions on `aud` and `sub`;
  `max_session_duration = 3600`; optional permissions boundary.
- Policies attached: never `AdministratorAccess` (validation, IAM-001).
- In the workflow: `aws-actions/configure-aws-credentials` with `role-to-assume`.

## Azure side (`modules/azure/github-oidc`)
- A **user-assigned managed identity** + `azurerm_federated_identity_credential` (issuer GitHub, audience
  `api://AzureADTokenExchange`, subject pinned).
- Role assignments scoped to the resource group, never Owner / User Access Administrator.
- In the workflow: `azure/login` with client-id, tenant-id, subscription-id (all non-secret), and
  `ARM_USE_OIDC=true` for Terraform.

## Bootstrap
The identity is created by the same Terraform it will later run, so the first apply is done once by an
administrator. After that, every change goes through the pipeline.

## Interview questions
1. **How do you give CI access to AWS without keys?** OIDC: GitHub's token is exchanged with STS
   AssumeRoleWithWebIdentity for a role whose trust policy pins repository and environment.
2. **What claims do you check?** `aud` (intended audience) and `sub` (repository + environment/branch); issuer is
   implied by the OIDC provider.
3. **What if the subject uses a wildcard?** Any branch or pull request workflow could assume the role: a
   privilege escalation path.
