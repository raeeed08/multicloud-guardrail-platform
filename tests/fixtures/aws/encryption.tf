# rules: ENC-001, ENC-002, KV-001
# expect: ENC-001
resource "aws_ebs_volume" "plain" {
  availability_zone = "eu-west-1a"
  size              = 20
}

# safe: the value comes from a variable, checked at runtime
resource "aws_ebs_volume" "from_var" {
  availability_zone = "eu-west-1a"
  size              = 20
  encrypted         = var.encrypted
}

# expect: ENC-001
resource "aws_db_instance" "plain" {
  engine            = "postgres"
  instance_class    = "db.t4g.micro"
  storage_encrypted = false
}

# expect: ENC-001
resource "aws_rds_cluster" "aurora" {
  engine = "aurora-postgresql"
}

# expect: ENC-002
resource "aws_kms_key" "no_rotation" {
  description = "data key"
}

# safe: asymmetric keys cannot rotate automatically
resource "aws_kms_key" "signing" {
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
}

# safe
resource "aws_kms_key" "rotated" {
  enable_key_rotation = true
}

# expect: KV-001
resource "aws_secretsmanager_secret" "force_delete" {
  name                    = "db-password"
  recovery_window_in_days = 0
}

# safe: default 30-day recovery window
resource "aws_secretsmanager_secret" "default" {
  name = "api-key"
}
