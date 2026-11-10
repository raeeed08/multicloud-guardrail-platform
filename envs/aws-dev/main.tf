# AWS landing zone for one workload account (dev).
#   security-baseline -> account-wide safety nets (S3 public block, EBS encryption, IMDSv2 default, GuardDuty...)
#   cloudtrail        -> multi-region audit trail, KMS, private bucket, tampering alarm
#   network           -> VPC, private subnets, locked default SG, flow logs, S3 gateway endpoint
#   kms + s3          -> encrypted, private data bucket
#   github-oidc       -> secretless CI/CD role
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Remote state: see backend.hcl.example (terraform init -backend-config=backend.hcl)
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      project     = "landing-zone"
      managed-by  = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  name   = "lz-${var.environment}"
  suffix = data.aws_caller_identity.current.account_id
}

module "baseline" {
  source       = "../../modules/aws/security-baseline"
  security_hub = var.security_hub
}

module "data_key" {
  source             = "../../modules/aws/kms"
  alias              = "${local.name}-data"
  description        = "Data at rest for ${local.name}"
  service_principals = ["logs.${var.region}.amazonaws.com"]
}

module "trail" {
  source      = "../../modules/aws/cloudtrail"
  name        = "${local.name}-trail"
  bucket_name = "${local.name}-cloudtrail-${local.suffix}"
}

module "network" {
  source      = "../../modules/aws/network"
  name_prefix = local.name
  cidr        = var.vpc_cidr
  enable_nat  = var.enable_nat
  kms_key_arn = module.data_key.key_arn
}

module "data_bucket" {
  source      = "../../modules/aws/s3-secure-bucket"
  name        = "${local.name}-data-${local.suffix}"
  kms_key_arn = module.data_key.key_arn
}

module "github_oidc" {
  source      = "../../modules/aws/github-oidc"
  role_name   = "${local.name}-github-deploy"
  subjects    = ["repo:${var.github_repository}:environment:${var.environment}"]
  policy_arns = var.deploy_policy_arns
}
