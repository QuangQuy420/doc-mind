# A child module declares which providers it needs so the root cannot hand it a
# provider it was never written against. The version pins match envs/dev; only
# the root module chooses the actual provider *configuration* (region, tags).
#
# `random` is a real provider, not a Terraform built-in: it is what generates
# the master password, and declaring it here is why `terraform init` adds it to
# the root lock file.
terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
