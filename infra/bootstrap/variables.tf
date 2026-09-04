variable "aws_region" {
  description = "AWS region for the state bucket and lock table. Must match the `region` in envs/dev/backend.tf."
  type        = string
  default     = "ap-southeast-1"
}
