output "state_bucket" {
  description = "Name of the S3 bucket holding remote state. Copy this into envs/dev/backend.tf."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table" {
  description = "Name of the DynamoDB table used for the classic state lock."
  value       = aws_dynamodb_table.tflock.name
}

output "account_id" {
  description = "AWS account id this stack was applied into."
  value       = data.aws_caller_identity.current.account_id
}
