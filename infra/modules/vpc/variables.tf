variable "name" {
  description = "Name prefix for every resource in this module (`docmind-<env>-<thing>`)."
  type        = string
  default     = "docmind-dev"
}

variable "cidr" {
  description = "IPv4 CIDR block of the VPC. /16 leaves room for 256 /24 subnets, so later tiers can be added without renumbering."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "How many availability zones to spread the subnets over. One public and one private subnet are created per AZ."
  type        = number
  default     = 2

  # Two is the floor, not a preference: an RDS subnet group requires subnets in
  # at least two AZs even for a single-AZ instance.
  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2 (RDS subnet groups require two AZs)."
  }
}

variable "enable_nat" {
  description = "Create the NAT Gateway and its Elastic IP. ~32 USD/month plus per-GB data processing while it exists, so it defaults to off."
  type        = bool
  default     = false
}
