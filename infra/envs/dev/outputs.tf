output "account_id" {
  description = "AWS account id this environment is applied into."
  value       = data.aws_caller_identity.current.account_id
}
