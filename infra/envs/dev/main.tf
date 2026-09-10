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

# The login system: user pool, the browser's public app client and the Hosted UI
# domain. Free at this scale (Essentials tier, first 10k monthly active users),
# so no cost toggle — and a toggle on an identity store would be a footgun
# anyway: flipping it back deletes every account.
module "cognito" {
  source = "../../modules/cognito"

  name       = "docmind-dev-users"
  aws_region = var.aws_region

  # Byte-for-byte redirect targets: the Vite dev server for local work and the
  # real SPA hostname, taken from the dns module's output so the name is built
  # in exactly one place. The trailing slash is part of the match.
  callback_urls = ["http://localhost:5173/", "https://${module.dns.site_fqdn}/"]
  logout_urls   = ["http://localhost:5173/", "https://${module.dns.site_fqdn}/"]
}

# The private registry for the API image. Always created: an empty repository
# costs nothing, and the image has to be pushed before `enable_ec2` is flipped
# on — a toggle here would mean apply, push, apply again.
module "ecr" {
  source = "../../modules/ecr"

  name = "docmind-dev-api"
}

# The API host: one t4g.small running the image behind Caddy, with an Elastic IP
# and the `api.<domain>` record. Behind a toggle at ~12 USD/month running — and
# ~5 USD/month even while stopped, because the EIP and the root volume keep
# billing. Flip it off (not just stop the instance) at the end of a session.
module "ec2_app" {
  source = "../../modules/ec2-app"
  count  = var.enable_ec2 ? 1 : 0

  name       = "docmind-dev"
  aws_region = var.aws_region

  # Element 0 is deterministically the subnet in AZ 0, so a re-apply never moves
  # the host to the other AZ.
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.app_sg_id

  zone_id     = module.dns.zone_id
  domain_name = var.domain_name

  image_url          = module.ecr.repository_url
  ecr_repository_arn = module.ecr.repository_arn

  dynamodb_table_arn = module.dynamodb.table_arn

  # Passing the resource attributes (not the literal name) is what makes the
  # log group exist before the instance boots into the `awslogs` driver.
  log_group_name = aws_cloudwatch_log_group.api.name
  log_group_arn  = aws_cloudwatch_log_group.api.arn

  # With `enable_rds = false` every one of these is null: user data then writes
  # no DATABASE_URL, runs no migration, and the role gets no SSM statement.
  rds_enabled                 = var.enable_rds
  rds_password_parameter_arn  = one(module.rds[*].password_parameter_arn)
  rds_password_parameter_name = one(module.rds[*].password_parameter_name)
  rds_host_parameter_arn      = one(module.rds[*].host_parameter_arn)
  rds_host_parameter_name     = one(module.rds[*].host_parameter_name)
  db_name                     = one(module.rds[*].db_name)
  db_username                 = one(module.rds[*].username)

  # Non-secret configuration only — user data is readable from the metadata
  # service. Keys match the settings fields in apps/api/app/core/config.py.
  api_env = {
    DYNAMODB_TABLE_NAME = module.dynamodb.table_name
    COGNITO_ISSUER      = module.cognito.issuer
    COGNITO_CLIENT_ID   = module.cognito.client_id

    # The SPA's real origin plus the Vite dev server. `site_fqdn` comes from the
    # dns module so the hostname is built in exactly one place, as the cognito
    # callback wiring above already does.
    CORS_ORIGINS = "https://${module.dns.site_fqdn},http://localhost:5173"

    LOG_LEVEL  = "INFO"
    AWS_REGION = var.aws_region
  }
}

# The SPA: a private bucket behind a CloudFront distribution on
# `https://app.<domain>`. No cost toggle — S3 storage for a few MB and
# CloudFront's free tier (1 TB out, 10M requests/month) make this effectively
# free, and a toggle would take the site down with it.
module "s3_site" {
  source = "../../modules/s3-site"

  # S3 bucket names are globally unique across every AWS account, so the account
  # id is part of the name — same trick as the state bucket in infra/bootstrap.
  bucket_name = "docmind-dev-site-${data.aws_caller_identity.current.account_id}"

  # Hostname, certificate and zone all come from the dns module: the name the
  # certificate was issued for, the name the alias record creates and the name
  # Cognito redirects back to are then one string in one place.
  site_fqdn       = module.dns.site_fqdn
  certificate_arn = module.dns.site_certificate_arn
  zone_id         = module.dns.zone_id
}
