# rules: DB-001
# expect: DB-001
resource "aws_db_instance" "public" {
  engine              = "mysql"
  instance_class      = "db.t4g.micro"
  storage_encrypted   = true
  publicly_accessible = true
}

# safe
resource "aws_db_instance" "private" {
  engine              = "mysql"
  instance_class      = "db.t4g.micro"
  storage_encrypted   = true
  publicly_accessible = false
}
