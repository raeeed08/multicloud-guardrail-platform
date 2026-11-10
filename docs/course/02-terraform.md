# 02: Terraform from zero

## What it is
Terraform (HashiCorp) describes infrastructure in a declarative language, **HCL**. You write the desired state;
Terraform computes the difference with reality and makes the API calls. It works with any cloud through
**providers** (`hashicorp/aws`, `hashicorp/azurerm`).

## The core loop
```bash
terraform init      # download providers and modules, configure the backend (state)
terraform fmt       # canonical formatting
terraform validate  # syntax and types, no cloud call
terraform plan      # compare code, state and reality: what would change?
terraform apply     # make the changes (asks for confirmation, or applies a saved plan)
terraform destroy   # delete everything this configuration manages
```

## Building blocks (all used in this repo)
```hcl
terraform {
  required_version = ">= 1.7"                       # Terraform CLI version
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }   # ~> 6.0 = any 6.x, never 7.0
  }
  backend "s3" {}                                   # where the state lives (configured at init)
}

provider "aws" {
  region = var.region
  default_tags { tags = { owner = "raed" } }        # applied to every resource (TAG-001)
}

variable "az_count" {                               # input
  type    = number
  default = 2
  validation {                                      # fails at plan time with a clear message
    condition     = var.az_count >= 2
    error_message = "Use at least 2 availability zones."
  }
}

locals { azs = slice(data.aws_availability_zones.available.names, 0, var.az_count) }   # computed values

data "aws_availability_zones" "available" {}        # read something that already exists

resource "aws_subnet" "private" {                   # create something
  count      = var.az_count                         # N copies (index-based)
  cidr_block = cidrsubnet(var.cidr, 4, count.index + 8)
}

resource "azurerm_storage_container" "this" {
  for_each = toset(var.containers)                  # one per key (stable identity)
  name     = each.value
}

module "network" {                                  # reuse a folder of Terraform
  source = "../../modules/aws/network"
  name_prefix = "lz-dev"
}

output "vpc_id" { value = module.network.vpc_id }   # expose values
```

Other constructs you will meet here:
- **`dynamic` blocks** generate nested blocks from a list (`dynamic "enabled_log"` in monitoring).
- **`lifecycle { precondition }`** checks an assumption before creating a resource (SCP size <= 5,120 chars).
- **`depends_on`** forces ordering when Terraform cannot infer it (bucket policy after public access block).
- **Conditional count**: `count = var.enable_nat ? 1 : 0` creates a resource only when wanted.

## State
Terraform records what it created in a **state file** (resource address -> real ID). It is how Terraform knows
that `aws_vpc.this` is `vpc-0abc...`. Rules:
- Store it **remotely** (S3 bucket / Azure storage account), **encrypted**, with **locking** so two people cannot
  apply at the same time. Here: `backend.hcl.example` files; S3 native locking (`use_lockfile = true`, Terraform
  1.10+) replaces the old DynamoDB table; Azure uses a blob lease.
- It can contain secrets: restrict access, never commit it (`.gitignore` has `*.tfstate`).

## Lock file
`.terraform.lock.hcl` pins the exact provider versions and checksums, so CI and laptops use the same provider.
Commit it for root configurations (`envs/*`), not for reusable modules.

## Modules and environments
- `modules/` = reusable building blocks with variables, outputs and tests.
- `envs/` = **root configurations** that call modules with real values. One state per environment.

## count vs for_each
`count` identifies copies by index: removing item 0 shifts every other item and Terraform recreates them.
`for_each` identifies by key: removing one key affects only that resource. Use `for_each` for anything named.

## Drift
Drift = reality differs from the code (someone changed the console). `terraform plan` shows it; Cloud Copilot
detects security-relevant drift continuously. Fix by changing the code (or importing), never by hand.

## Commands to know
```bash
terraform init -backend=false            # init without state (CI checks, tests)
terraform init -backend-config=backend.hcl
terraform plan -out tfplan               # save the exact plan
terraform apply tfplan                   # apply exactly what was reviewed
terraform state list / show <addr>       # inspect state
terraform import <addr> <id>             # adopt an existing resource
terraform providers schema -json         # every argument of every resource (used to check names here)
terraform test                           # run *.tftest.hcl files
```

## Interview questions
1. **What is Terraform state and why remote?** The map between code and real resources; remote for sharing,
   locking, encryption and to avoid losing it.
2. **Plan vs apply?** Plan computes the diff without changing anything; apply executes it. In CI, apply the
   saved plan that was reviewed.
3. **count vs for_each?** Index vs stable key identity; prefer for_each.
4. **How do you manage environments?** Separate root configurations (or workspaces) with separate state, the same
   modules and different variables.
5. **What does `~> 6.0` mean?** Any version >= 6.0 and < 7.0: minor upgrades yes, breaking major no.
6. **How do you avoid secrets in Terraform?** Variables from the environment or a vault, no secrets in state
   where avoidable, managed identities and OIDC instead of keys.
