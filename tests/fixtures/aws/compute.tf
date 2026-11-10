# rules: CMP-001
# expect: CMP-001
resource "aws_instance" "legacy" {
  ami           = "ami-123"
  instance_type = "t3.micro"
}

# expect: CMP-001
resource "aws_launch_template" "optional_tokens" {
  name = "web"
  metadata_options {
    http_tokens = "optional"
  }
}

# safe
resource "aws_instance" "hardened" {
  ami           = "ami-123"
  instance_type = "t3.micro"
  metadata_options {
    http_tokens = "required"
  }
}
