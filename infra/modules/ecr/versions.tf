# A child module declares which providers it needs so the root cannot hand it a
# provider it was never written against. The version pins match envs/dev; only
# the root module chooses the actual provider *configuration* (region, tags).
terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
