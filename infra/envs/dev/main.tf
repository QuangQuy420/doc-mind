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

# The hosted zone for the domain and the CloudFront certificate for the SPA.
# The certificate must be issued in us-east-1, so the module is handed both the
# default provider and the aliased one; a module never picks a region itself.
module "dns" {
  source = "../../modules/dns"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name   = var.domain_name
  site_hostname = "app"
}

# The `documents` table. No cost toggle: on-demand billing means it costs
# nothing while nothing reads or writes it, and a toggle on a data store is a
# footgun — flipping it back deletes the data.
module "dynamodb" {
  source = "../../modules/dynamodb"

  name = "docmind-dev-documents"
}

# PostgreSQL for the relational data and (from P7) the pgvector chunks. Behind a
# toggle at ~12-15 USD/month.
#
# Careful: unlike the other toggles this one is NOT flipped back at the end of a
# session. `enable_rds = false` + apply DESTROYS the instance and, with
# `skip_final_snapshot = true`, its data. Stop the instance instead — see
# "Teardown between sessions" in infra/README.md.
module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

  identifier = "docmind-dev-postgres"
  ssm_prefix = "/docmind/dev/rds"

  # Private subnets and the 5432-from-app-only security group both come from the
  # vpc module's outputs; nothing is hard-coded here.
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.vpc.rds_sg_id
}
