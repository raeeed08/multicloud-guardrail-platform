# Customer-managed KMS key with automatic rotation (ENC-002). The key policy keeps the account in control
# and optionally lets AWS services (CloudTrail, CloudWatch Logs, ...) use the key for this account only.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "key" {
  #checkov:skip=CKV_AWS_109:Key policy. Resource "*" means this key only; the account-root statement is the AWS default key policy.
  #checkov:skip=CKV_AWS_111:Key policy. Resource "*" means this key only.
  #checkov:skip=CKV_AWS_356:Key policy. Resource "*" means this key only.
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = var.service_principals
    content {
      sid       = "Allow${replace(title(replace(statement.value, ".", " ")), " ", "")}"
      actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = [statement.value]
      }
      # CloudWatch Logs identifies itself through the encryption context; other services send SourceAccount.
      condition {
        test     = startswith(statement.value, "logs.") ? "ArnLike" : "StringEquals"
        variable = startswith(statement.value, "logs.") ? "kms:EncryptionContext:aws:logs:arn" : "aws:SourceAccount"
        values = [startswith(statement.value, "logs.")
          ? "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        : data.aws_caller_identity.current.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true # ENC-002
  rotation_period_in_days = var.rotation_days
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.this.key_id
}
