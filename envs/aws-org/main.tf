# Organisation guardrails, applied with credentials of the AWS Organizations management account.
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1" # Organizations is a global service served from us-east-1
  default_tags {
    tags = {
      owner       = var.owner
      environment = "org"
      project     = "landing-zone"
      managed-by  = "terraform"
    }
  }
}

module "scps" {
  source           = "../../modules/aws/org-guardrails"
  target_ids       = var.target_ou_ids
  allowed_regions  = var.allowed_regions
  exempt_role_arns = var.exempt_role_arns
}
