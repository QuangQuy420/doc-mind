# The URL is what `docker push` and `docker pull` address; the ARN is what an
# IAM policy is scoped to. Both are needed by P8, so both are exposed.
output "repository_url" {
  description = "Registry URL of the repository (`<account>.dkr.ecr.<region>.amazonaws.com/<name>`), without a tag."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the repository, so the instance role's pull permissions are scoped to it instead of `*`."
  value       = aws_ecr_repository.this.arn
}
