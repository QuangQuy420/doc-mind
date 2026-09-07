# Marked sensitive so the endpoint never lands in CI logs or a shared
# `terraform output` dump. It is not secret in itself, but it is half of what an
# attacker needs, and the value is available from the SSM parameter anyway.
output "endpoint_address" {
  description = "Endpoint hostname of the instance (no port). Use `terraform output -raw rds_endpoint_address` to read it."
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "port" {
  description = "Port the instance listens on (5432 for PostgreSQL)."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the database created inside the instance."
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Master username. Not secret on its own; the password is only in SSM."
  value       = aws_db_instance.this.username
}

# The ARNs are what IAM policies are scoped to; the names are what a caller
# passes to `ssm:GetParameter`. P8 needs both.
output "password_parameter_arn" {
  description = "ARN of the SecureString parameter holding the master password. P8 scopes the instance role's `ssm:GetParameter` to it."
  value       = aws_ssm_parameter.master_password.arn
}

output "password_parameter_name" {
  description = "Name (path) of the master password parameter, e.g. `/docmind/dev/rds/master_password`."
  value       = aws_ssm_parameter.master_password.name
}

output "host_parameter_arn" {
  description = "ARN of the parameter holding the endpoint hostname."
  value       = aws_ssm_parameter.host.arn
}

output "host_parameter_name" {
  description = "Name (path) of the host parameter, e.g. `/docmind/dev/rds/host`."
  value       = aws_ssm_parameter.host.name
}
