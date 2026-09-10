# A child module declares which providers it needs so the root cannot hand it a
# provider it was never written against. The version pins match envs/dev; only
# the root module chooses the actual provider *configuration* (region, tags).
#
# No `configuration_aliases` here even though CloudFront is a global service and
# its certificate must live in us-east-1: the certificate is created by the `dns`
# module and arrives as an ARN, so this module never talks to us-east-1 itself.
terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
