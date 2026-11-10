# rules: NET-001, NET-002, NET-003
resource "aws_security_group" "web" {
  name = "web"

  # expect: NET-001
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # expect: NET-001
  # expect: NET-002  (the range also contains MySQL 3306)
  ingress {
    from_port        = 3000
    to_port          = 4000
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  # safe: HTTPS from the internet is the purpose of a web tier
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # safe: SSH from the private network only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # safe: UDP cannot carry SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# expect: NET-002
resource "aws_security_group_rule" "postgres_public" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-123"
}

# expect: NET-003
resource "aws_security_group_rule" "all_tcp" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-123"
}

# expect: NET-001
resource "aws_security_group_rule" "low_ports" {
  type              = "ingress"
  from_port         = 0
  to_port           = 1024
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-123"
}

# safe: egress is not exposure
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-123"
}

# expect: NET-003
resource "aws_vpc_security_group_ingress_rule" "everything" {
  security_group_id = "sg-123"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# expect: NET-002
resource "aws_vpc_security_group_ingress_rule" "mongo_ipv6" {
  security_group_id = "sg-123"
  ip_protocol       = "tcp"
  from_port         = 27017
  to_port           = 27017
  cidr_ipv6         = "::/0"
}

# safe: database reachable only from the application security group
resource "aws_vpc_security_group_ingress_rule" "postgres_from_app" {
  security_group_id            = "sg-123"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = "sg-app"
}
