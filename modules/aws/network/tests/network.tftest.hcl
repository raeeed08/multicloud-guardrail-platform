mock_provider "aws" {
  # Policy documents must render as valid JSON for resources that validate it.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{}"
      minified_json = "{}"
    }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-1"
    }
  }
}

variables {
  name_prefix = "lz-test"
}

run "two_zones_no_nat_by_default" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 2 && length(aws_subnet.public) == 2
    error_message = "One public and one private subnet per zone."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "NAT is opt-in (cost)."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "No automatic public IPs."
  }

  assert {
    condition     = length(aws_default_security_group.locked.ingress) == 0 && length(aws_default_security_group.locked.egress) == 0
    error_message = "The default security group must have no rules."
  }

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL"
    error_message = "Flow logs must capture accepted and rejected traffic."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.service_name == "com.amazonaws.eu-west-1.s3"
    error_message = "S3 gateway endpoint must target the current region."
  }
}

run "nat_when_requested" {
  command = plan

  variables {
    enable_nat = true
    az_count   = 3
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_subnet.private) == 3
    error_message = "One NAT gateway and three private subnets expected."
  }
}

run "rejects_single_zone" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_short_flow_log_retention" {
  command = plan

  variables {
    flow_log_retention_days = 30
  }

  expect_failures = [var.flow_log_retention_days]
}
