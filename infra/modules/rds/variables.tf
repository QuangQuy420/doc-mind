variable "identifier" {
  description = "DB instance identifier (`docmind-<env>-postgres`). No default: the environment name belongs to the root module, not to a reusable module."
  type        = string
}

variable "ssm_prefix" {
  description = "Parameter Store path the credentials are written under, without a trailing slash (e.g. `/docmind/dev/rds`). Readers get `ssm:GetParameter` on `<ssm_prefix>/*` only."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet ids for the DB subnet group. At least two AZs are required, even for a single-AZ instance."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the instance. Expected to allow 5432 from the app security group only."
  type        = string
}

variable "db_name" {
  description = "Name of the database created inside the instance."
  type        = string
  default     = "docmind"
}

variable "username" {
  description = "Master username. Cannot be `postgres`, `admin` or another reserved word."
  type        = string
  default     = "docmind"
}

variable "instance_class" {
  description = "Instance size. `db.t4g.micro` is the smallest Graviton class: cheapest, and its low `max_connections` is a useful reason to keep the API's pool small."
  type        = string
  default     = "db.t4g.micro"
}
