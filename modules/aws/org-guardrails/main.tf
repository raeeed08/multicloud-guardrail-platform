# Service Control Policies (the AWS GUARD layer). Applied from the Organizations management account to OUs;
# they cap what ANY identity in member accounts can do, administrators included. A break-glass role is exempt.
# SCPs are limited to 5,120 characters each, so the guardrails are split by theme.
locals {
  exempt = length(var.exempt_role_arns) > 0
}

data "aws_iam_policy_document" "protect_security" {
  statement {
    sid    = "ProtectAuditAndDetection"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging", "cloudtrail:DeleteTrail", "cloudtrail:UpdateTrail", "cloudtrail:PutEventSelectors",
      "guardduty:DeleteDetector", "guardduty:DisassociateFromMasterAccount", "guardduty:UpdateDetector",
      "access-analyzer:DeleteAnalyzer",
      "securityhub:DisableSecurityHub",
      "config:StopConfigurationRecorder", "config:DeleteConfigurationRecorder",
    ]
    resources = ["*"]
    dynamic "condition" {
      for_each = local.exempt ? [1] : []
      content {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.exempt_role_arns
      }
    }
  }

  statement {
    sid       = "DenyLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }
}

data "aws_iam_policy_document" "data_protection" {
  # STO-001: nobody can weaken the account-level S3 public access block.
  statement {
    sid       = "ProtectS3PublicAccessBlock"
    effect    = "Deny"
    actions   = ["s3:PutAccountPublicAccessBlock", "s3:DeleteAccountPublicAccessBlock"]
    resources = ["*"]
    dynamic "condition" {
      for_each = local.exempt ? [1] : []
      content {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.exempt_role_arns
      }
    }
  }

  # CMP-001: instances must be launched with IMDSv2.
  statement {
    sid       = "RequireImdsV2"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringNotEquals"
      variable = "ec2:MetadataHttpTokens"
      values   = ["required"]
    }
  }

  # ENC-001: unencrypted volumes cannot be created.
  statement {
    sid       = "RequireEncryptedVolumes"
    effect    = "Deny"
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "ec2:Encrypted"
      values   = ["false"]
    }
  }

  # IAM-002: no new long-lived access keys.
  statement {
    sid       = "DenyAccessKeyCreation"
    effect    = "Deny"
    actions   = ["iam:CreateAccessKey"]
    resources = ["*"]
    dynamic "condition" {
      for_each = local.exempt ? [1] : []
      content {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.exempt_role_arns
      }
    }
  }
}

# GOV-001: only approved regions. Global services (IAM, Organizations, CloudFront, Route 53, support...)
# are excluded with NotAction because they are served from us-east-1.
data "aws_iam_policy_document" "regions" {
  statement {
    sid    = "DenyUnapprovedRegions"
    effect = "Deny"
    not_actions = [
      "a4b:*", "acm:*", "aws-marketplace-management:*", "aws-marketplace:*", "aws-portal:*", "budgets:*",
      "ce:*", "chime:*", "cloudfront:*", "config:*", "cur:*", "directconnect:*", "ec2:DescribeRegions",
      "ec2:DescribeTransitGateways", "ec2:DescribeVpnGateways", "fms:*", "globalaccelerator:*", "health:*",
      "iam:*", "importexport:*", "kms:*", "mobileanalytics:*", "networkmanager:*", "organizations:*",
      "pricing:*", "route53:*", "route53domains:*", "route53-recovery-cluster:*", "route53-recovery-control-config:*",
      "route53-recovery-readiness:*", "s3:GetAccountPublic*", "s3:ListAllMyBuckets", "s3:ListMultiRegionAccessPoints",
      "s3:PutAccountPublic*", "shield:*", "sts:*", "support:*", "trustedadvisor:*", "waf-regional:*", "waf:*",
      "wafv2:*", "wellarchitected:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
    dynamic "condition" {
      for_each = local.exempt ? [1] : []
      content {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.exempt_role_arns
      }
    }
  }
}

locals {
  policies = {
    protect-security = { description = "Audit and detection cannot be disabled; no root user; cannot leave the org", json = data.aws_iam_policy_document.protect_security.minified_json }
    data-protection  = { description = "S3 public access block, IMDSv2, encrypted volumes, no access keys", json = data.aws_iam_policy_document.data_protection.minified_json }
    regions          = { description = "GOV-001: only ${join(", ", var.allowed_regions)}", json = data.aws_iam_policy_document.regions.minified_json }
  }
}

resource "aws_organizations_policy" "this" {
  for_each    = local.policies
  name        = "lz-${each.key}"
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.json
  tags        = var.tags

  lifecycle {
    precondition {
      condition     = length(each.value.json) <= 5120
      error_message = "SCP ${each.key} is ${length(each.value.json)} characters; AWS allows 5120. Split it."
    }
  }
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = {
    for pair in setproduct(keys(local.policies), var.target_ids) : "${pair[0]}/${pair[1]}" => { policy = pair[0], target = pair[1] }
  }
  policy_id = aws_organizations_policy.this[each.value.policy].id
  target_id = each.value.target
}
