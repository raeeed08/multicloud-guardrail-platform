# 08: The AWS landing zone (`envs/aws-dev`, `envs/aws-org`)

## Accounts and Organizations
An **AWS account** is the strongest isolation boundary (blast radius, billing, quotas). **AWS Organizations**
groups accounts into **OUs** and applies **SCPs** (service control policies) to them. Typical OUs: Security
(log archive, audit), Infrastructure, Workloads (dev/prod), Sandbox.

## Network (`modules/aws/network`)
- **VPC** 10.20.0.0/16, public and private subnets in 2+ availability zones (`cidrsubnet`).
- Public subnets route `0.0.0.0/0` to the **internet gateway**, but `map_public_ip_on_launch = false`.
- Private subnets have no internet route unless `enable_nat = true` (one NAT gateway, about 32 USD/month + data:
  the most expensive line of a small VPC, so opt-in).
- **S3 gateway endpoint**: free; S3 traffic stays on AWS and avoids NAT data charges.
- **Default security group locked** (`ingress = []`, `egress = []`): nothing can accidentally use it.
- **VPC flow logs** (ALL traffic) to CloudWatch Logs, encrypted with KMS, 90+ days, through a least-privilege role.
- Security groups are **stateful** (return traffic allowed); NACLs are stateless, subnet-level.

## KMS (`modules/aws/kms`)
Customer-managed key with `enable_key_rotation = true` (ENC-002, yearly by default), 30-day deletion window,
and a **key policy**: the account root administers the key (the AWS default, which delegates to IAM), and named
services can use it, CloudWatch Logs via the `kms:EncryptionContext:aws:logs:arn` condition and other services
via `aws:SourceAccount` (prevents the "confused deputy" problem).

## Secure S3 bucket (`modules/aws/s3-secure-bucket`)
| Setting | Why | Rule |
|---|---|---|
| Block Public Access (4 settings) | bucket can never be public | STO-001 |
| `BucketOwnerEnforced` ownership | ACLs disabled, policies only | STO-001 |
| SSE-KMS + bucket key | encryption at rest, fewer KMS calls (cost) | ENC |
| bucket policy: deny `aws:SecureTransport = false` and `s3:TlsVersion < 1.2` | TLS only | STO-002 |
| versioning + lifecycle (expire old versions, abort uploads) | recovery + cost control | |

## CloudTrail (`modules/aws/cloudtrail`)
The audit log of every API call. Here: **multi-region**, global service events, **log file validation**
(SHA-256 digest files prove logs were not modified), KMS encryption, delivery to a private bucket (the bucket
policy allows CloudTrail only for this trail ARN), and CloudWatch Logs with a **metric filter + alarm** on
StopLogging, DeleteTrail, DeleteDetector, public access block changes and security group ingress changes.

## Security baseline (`modules/aws/security-baseline`), applied once per account
| Control | Effect |
|---|---|
| `aws_s3_account_public_access_block` | no bucket in the account can be public |
| `aws_ebs_encryption_by_default` | every new volume encrypted |
| `aws_ebs_snapshot_block_public_access` | snapshots cannot be shared publicly |
| `aws_ec2_instance_metadata_defaults` | IMDSv2 by default for new instances |
| password policy | CIS 1.8-1.9 |
| **IAM Access Analyzer** | finds resources shared outside the account |
| **GuardDuty** (+ S3 protection) | threat detection from CloudTrail, VPC flow logs, DNS logs |
| Security Hub + CIS v3.0 | optional (paid) |

**IMDSv2** requires a session token obtained with a PUT, which SSRF bugs usually cannot send; IMDSv1 is how the
2019 Capital One breach stole instance credentials.

## SCPs (`modules/aws/org-guardrails`): the GUARD layer
SCPs **cap** permissions: they never grant, they set the maximum for every identity in member accounts (root
user included, not the management account). Three policies (each under the 5,120-character limit, enforced by
a precondition on the minified JSON):
- **protect-security**: cannot stop/delete CloudTrail, GuardDuty, Access Analyzer, Config, Security Hub; cannot
  leave the organisation; root user denied.
- **data-protection**: cannot change the account S3 public access block; `ec2:RunInstances` denied unless
  `ec2:MetadataHttpTokens = required`; unencrypted volumes denied; no new access keys.
- **regions** (GOV-001): deny outside approved regions, except global services (IAM, Organizations, Route 53,
  CloudFront, support...) via `NotAction`.
A **break-glass role** is exempt (`ArnNotLike aws:PrincipalArn`). Roll out on a sandbox OU first.

## Interview questions
1. **SCP vs IAM policy?** IAM grants within an account; an SCP sets the maximum permissions for accounts in an
   OU. Effective permission = intersection; an explicit deny anywhere wins.
2. **Security group vs NACL?** Stateful, allow-only, per ENI vs stateless, allow and deny, per subnet.
3. **How do you protect CloudTrail?** Multi-region, log validation, KMS, separate log archive account, bucket
   policy limited to the trail, SCP denying StopLogging/DeleteTrail, alarm on tampering.
4. **Why IMDSv2?** Session tokens via PUT defeat most SSRF credential theft.
5. **How would you reduce VPC costs?** No NAT where not needed, gateway endpoints for S3/DynamoDB, fewer
   interface endpoints, right-sized flow log retention.
