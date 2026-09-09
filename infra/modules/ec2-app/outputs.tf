output "instance_id" {
  description = "Id of the app instance. `aws ssm start-session --target <id>` opens a shell on it."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP the `api` record points at. Stable across instance replacements."
  value       = aws_eip.this.public_ip
}

output "api_url" {
  description = "Base URL the API answers on once Caddy has its Let's Encrypt certificate."
  value       = "https://${aws_route53_record.api.name}"
}
