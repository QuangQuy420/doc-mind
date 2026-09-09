variable "name" {
  description = "Name prefix for the instance, its role and its instance profile (`docmind-<env>`). No default: the environment name belongs to the root module, not to a reusable module."
  type        = string
}

variable "aws_region" {
  description = "Region the instance runs in. Passed into user data because the `aws` CLI and the Docker `awslogs` driver both need it spelled out; a module never picks a region itself."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size. `t4g.small` is Graviton (arm64) — ~20 % cheaper than the x86 equivalent, which is why the image is built for arm64. 2 GB of RAM is what makes room for uvicorn plus Caddy plus the pip-free container."
  type        = string
  default     = "t4g.small"
}

# --- Network ------------------------------------------------------------------

variable "subnet_id" {
  description = "Public subnet the instance is placed in. Public because Caddy needs inbound 80/443 from Let's Encrypt and the internet, and because there is no NAT gateway to give a private subnet egress."
  type        = string
}

variable "security_group_id" {
  description = "Security group attached to the instance. Expected to allow inbound 80/443 only — there is no port 22 rule anywhere; shell access is SSM Session Manager."
  type        = string
}

# --- DNS ----------------------------------------------------------------------

variable "zone_id" {
  description = "Route 53 hosted zone the API's A record is created in."
  type        = string
}

variable "domain_name" {
  description = "Bare root domain (e.g. example.com). The API answers on `<api_hostname>.<domain_name>`."
  type        = string
}

variable "api_hostname" {
  description = "Hostname of the API under the root domain. Caddy asks Let's Encrypt for a certificate for exactly this name, so it must resolve to the instance before the first HTTPS request."
  type        = string
  default     = "api"
}

# --- Image --------------------------------------------------------------------

variable "image_url" {
  description = "ECR repository URL to pull the API image from, without a tag (`<account>.dkr.ecr.<region>.amazonaws.com/<repo>`)."
  type        = string
}

variable "image_tag" {
  description = "Tag pulled at boot. `latest` on a MUTABLE repository means 'whatever was pushed last' — fine in dev, where the instance is replaced to pick a new image up."
  type        = string
  default     = "latest"
}

variable "ecr_repository_arn" {
  description = "ARN of the repository, so the pull permissions are scoped to it instead of `*`."
  type        = string
}

# --- Data stores and logs -----------------------------------------------------

variable "dynamodb_table_arn" {
  description = "ARN of the documents table. The instance role gets `Query`/`PutItem` on it only."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group the Docker `awslogs` driver writes both containers into."
  type        = string
}

variable "log_group_arn" {
  description = "ARN of that log group. The role's `PutLogEvents` is scoped to `<arn>:*` — the streams inside the group."
  type        = string
}

# --- Database (only wired when the RDS toggle is on) --------------------------

variable "rds_enabled" {
  description = "Whether an RDS instance exists. False means user data writes no `DATABASE_URL`, runs no migration, and the role gets no `ssm:GetParameter` statement at all — the API still starts and reports `database: error` on /health."
  type        = bool
}

variable "rds_password_parameter_arn" {
  description = "ARN of the SecureString parameter holding the master password. Null while `rds_enabled = false`."
  type        = string
  default     = null
}

variable "rds_password_parameter_name" {
  description = "Name (path) of that parameter — what `aws ssm get-parameter --name` in user data takes. Null while `rds_enabled = false`."
  type        = string
  default     = null
}

variable "rds_host_parameter_arn" {
  description = "ARN of the parameter holding the endpoint hostname. Null while `rds_enabled = false`."
  type        = string
  default     = null
}

variable "rds_host_parameter_name" {
  description = "Name (path) of the host parameter. Null while `rds_enabled = false`."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Database name inside the instance, used to build `DATABASE_URL`. Null while `rds_enabled = false`."
  type        = string
  default     = null
}

variable "db_username" {
  description = "Master username, used to build `DATABASE_URL`. Not a secret; the password is read from SSM at boot and never appears in user data."
  type        = string
  default     = null
}

# --- Application configuration ------------------------------------------------

variable "api_env" {
  description = "Non-secret environment variables written verbatim into /opt/docmind/api.env (`DYNAMODB_TABLE_NAME`, `COGNITO_ISSUER`, `COGNITO_CLIENT_ID`, `CORS_ORIGINS`, `LOG_LEVEL`, `AWS_REGION`). Keys must match the field names in apps/api/app/core/config.py. Never put a secret here — user data is readable from the instance metadata by anything on the box."
  type        = map(string)
}
