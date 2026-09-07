variable "aws_region" {
  description = "AWS region for every regional resource in this environment. Must match the `region` in backend.tf."
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Root domain for the app (e.g. example.com). Required since P4."
  type        = string

  # Catches the usual paste mistakes early (a URL, a trailing dot, capitals):
  # Route 53 would accept some of them and then never match what the registrar
  # delegates.
  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a bare domain, lowercase, no scheme, no trailing dot."
  }
}

variable "budget_email" {
  description = "Email address that receives the AWS Budget alerts. Set it in dev.auto.tfvars; no confirmation email is needed for budgets."
  type        = string
}

# --- Cost toggles: default false, flip on only while actively testing ---------

variable "enable_nat" {
  description = "Create the NAT Gateway (Phase 3 VPC). ~32 USD/month plus per-GB data processing while it exists."
  type        = bool
  default     = false
}

variable "enable_rds" {
  description = "Create the RDS PostgreSQL instance (Phase 5). ~12-15 USD/month for db.t4g.micro outside the free tier."
  type        = bool
  default     = false
}

variable "enable_ec2" {
  description = "Create the EC2 app instance (Phase 8). ~12 USD/month for a t4g.small running 24/7, plus ~3.6 USD/month for its EIP while the instance is stopped."
  type        = bool
  default     = false
}

variable "enable_cost_allocation_tag" {
  description = "Activate the `Project` cost allocation tag. Free, but AWS only accepts it once the tag has appeared on a billed resource (~24h after the first one). Leave false until then."
  type        = bool
  default     = false
}
