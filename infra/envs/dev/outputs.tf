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
