# Root module for the dev environment.
#
# Child modules are wired here as each phase lands — see .plans/00-overview.md
# for the roadmap and infra/README.md for the module boundaries table
# (vpc, dns, rds, dynamodb, cognito, ec2-app, s3-site).

data "aws_caller_identity" "current" {}

# The network everything else lives in. Free while `enable_nat = false`: the
# VPC, subnets, route tables, IGW and the two gateway endpoints are not billed.
module "vpc" {
  source = "../../modules/vpc"

  name       = "docmind-dev"
  cidr       = "10.0.0.0/16"
  az_count   = 2
  enable_nat = var.enable_nat
}
