output "account_id" {
  description = "AWS account id this environment is applied into."
  value       = data.aws_caller_identity.current.account_id
}

# --- Network (module `vpc`) ---------------------------------------------------
# Re-exported so `terraform output` in this directory is the one place to look
# up the ids the owner needs when reading the console or wiring the next phase.

output "vpc_id" {
  description = "Id of the dev VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet ids, ordered by AZ index. P8 puts the EC2 host in element 0."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet ids, ordered by AZ index. P5 uses them for the RDS subnet group."
  value       = module.vpc.private_subnet_ids
}

output "app_sg_id" {
  description = "Security group for the API host: inbound 80/443, all outbound."
  value       = module.vpc.app_sg_id
}

output "rds_sg_id" {
  description = "Security group for the database: inbound 5432 from the app security group only."
  value       = module.vpc.rds_sg_id
}

# --- DNS (module `dns`) -------------------------------------------------------

output "zone_id" {
  description = "Hosted zone id for the domain. P8 and P9 add their records in it."
  value       = module.dns.zone_id
}

output "name_servers" {
  description = "The four Route 53 name servers to set at the registrar; see the `DNS delegation` section of infra/README.md."
  value       = module.dns.name_servers
}

output "site_certificate_arn" {
  description = "ARN of the validated us-east-1 certificate for the SPA hostname. P9 attaches it to CloudFront."
  value       = module.dns.site_certificate_arn
}

# --- Documents table (module `dynamodb`) --------------------------------------

output "dynamodb_table_name" {
  description = "Name of the documents table. P7 passes it to the API as an environment variable."
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the documents table, for scoping IAM policies to it."
  value       = module.dynamodb.table_arn
}

output "dynamodb_stream_arn" {
  description = "ARN of the table's stream. P2 uses it as the event source of the notify lambda."
  value       = module.dynamodb.stream_arn
}

# --- Database (module `rds`) --------------------------------------------------
# `one()` turns the count-based module's list into a single value, or `null`
# when `enable_rds = false` — so `terraform output` still works with RDS off.

output "rds_password_parameter_arn" {
  description = "ARN of the SSM SecureString holding the master password. Null while `enable_rds = false`. P8 scopes the instance role to it."
  value       = one(module.rds[*].password_parameter_arn)
}

output "rds_host_parameter_arn" {
  description = "ARN of the SSM parameter holding the endpoint hostname. Null while `enable_rds = false`."
  value       = one(module.rds[*].host_parameter_arn)
}

output "rds_endpoint_address" {
  description = "Endpoint hostname of the database. Read it with `terraform output -raw rds_endpoint_address`; the same value is in the `host` SSM parameter."
  value       = one(module.rds[*].endpoint_address)
  sensitive   = true
}

# --- Auth (module `cognito`) --------------------------------------------------

output "cognito_user_pool_id" {
  description = "Id of the user pool. Used for AWS CLI admin calls (creating or confirming a test user)."
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Id of the SPA app client. P7 passes it to the API as `COGNITO_CLIENT_ID`; P9 builds the SPA with it as `VITE_COGNITO_CLIENT_ID`."
  value       = module.cognito.client_id
}

output "cognito_issuer" {
  description = "OIDC issuer URL of the pool. P7 passes it to the API as `COGNITO_ISSUER` and fetches the JWKS from `<issuer>/.well-known/jwks.json`."
  value       = module.cognito.issuer
}

output "cognito_hosted_ui_domain" {
  description = "Base URL of the Hosted UI. Append the `/login?client_id=…&response_type=code&scope=openid+email+profile&redirect_uri=…` query to reach the login page."
  value       = module.cognito.hosted_ui_domain
}

# --- API image (module `ecr`) -------------------------------------------------

output "ecr_repository_url" {
  description = "Registry URL to tag and push the API image to. Always present — the repository is not behind a toggle."
  value       = module.ecr.repository_url
}

# --- API host (module `ec2-app`) ----------------------------------------------
# All three are null while `enable_ec2 = false`, so `terraform output` still
# works with the instance off.

output "api_url" {
  description = "Base URL the API answers on, e.g. https://api.example.com. Null while `enable_ec2 = false`."
  value       = one(module.ec2_app[*].api_url)
}

output "ec2_instance_id" {
  description = "Id of the API host. `aws ssm start-session --target $(terraform output -raw ec2_instance_id)` opens a shell on it. Null while `enable_ec2 = false`."
  value       = one(module.ec2_app[*].instance_id)
}

output "ec2_public_ip" {
  description = "Elastic IP the `api` record points at. Stable across instance replacements. Null while `enable_ec2 = false`."
  value       = one(module.ec2_app[*].public_ip)
}

# --- SPA site (module `s3-site`) ----------------------------------------------
# The three values the web build and the deploy script need; see
# "The SPA site (Phase 9)" in infra/README.md.

output "site_url" {
  description = "Base URL of the SPA, without a trailing slash. The SPA is built with `VITE_REDIRECT_URI=<site_url>/` — the trailing slash is part of Cognito's byte-for-byte callback match."
  value       = module.s3_site.site_url
}

output "site_bucket_name" {
  description = "Name of the site bucket. The deploy script reads it as `SITE_BUCKET`."
  value       = module.s3_site.bucket_name
}

output "cloudfront_distribution_id" {
  description = "Id of the SPA distribution. The deploy script reads it as `CF_DIST_ID` to invalidate `/` and `/index.html`."
  value       = module.s3_site.distribution_id
}
