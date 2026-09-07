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
