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
