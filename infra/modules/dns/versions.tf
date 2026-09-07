# A child module declares which providers it needs so the root cannot hand it a
# provider it was never written against. The version pins match envs/dev; only
# the root module chooses the actual provider *configuration* (region, tags).
#
# `configuration_aliases` additionally declares "this module also needs a second
# aws configuration, named aws.us_east_1". The root must pass it explicitly with
# a `providers = {}` block — the module never creates a provider of its own.
terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
