output "table_name" {
  description = "Name of the documents table. The API and the lambdas take it from here as an environment variable."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the table, so IAM policies can be scoped to it instead of `*`. Index policies need `<table_arn>/index/*` as well."
  value       = aws_dynamodb_table.this.arn
}

output "stream_arn" {
  description = "ARN of the current stream. P2 uses it as the event source of the notify lambda. It changes if the stream is disabled and re-enabled."
  value       = aws_dynamodb_table.this.stream_arn
}
