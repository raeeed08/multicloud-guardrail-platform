# rules: TAG-001
# expect: TAG-001
provider "aws" {
  region = "eu-west-1"
}

# expect: TAG-001
provider "aws" {
  alias  = "us"
  region = "us-east-1"
  default_tags {
    tags = { owner = "platform" }
  }
}

# safe
provider "aws" {
  alias  = "eu_central"
  region = "eu-central-1"
  default_tags {
    tags = { owner = "platform", environment = "dev", project = "landing-zone" }
  }
}

# safe: tags come from a variable, checked at runtime
provider "aws" {
  alias  = "from_var"
  region = "eu-west-3"
  default_tags {
    tags = var.tags
  }
}
