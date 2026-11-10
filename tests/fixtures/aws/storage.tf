# rules: STO-001
# expect: STO-001
resource "aws_s3_bucket_public_access_block" "partial" {
  bucket                  = "data"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# expect: STO-001
resource "aws_s3_account_public_access_block" "off" {}

# expect: STO-001
resource "aws_s3_bucket_acl" "public" {
  bucket = "data"
  acl    = "public-read"
}

# safe
resource "aws_s3_bucket_public_access_block" "locked" {
  bucket                  = "data"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# safe
resource "aws_s3_bucket_acl" "private" {
  bucket = "data"
  acl    = "private"
}
