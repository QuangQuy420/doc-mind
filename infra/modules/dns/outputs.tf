output "zone_id" {
  description = "Hosted zone id. P8 adds the `api` A record and P9 the `app` alias record in this zone."
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "The four Route 53 name servers to set at the registrar. They change if the zone is recreated."
  value       = aws_route53_zone.this.name_servers
}

# Taken from the validation resource, not the certificate: reading it that way
# makes every consumer wait until the status is Issued.
output "site_certificate_arn" {
  description = "ARN of the validated us-east-1 certificate for the SPA hostname. P9 attaches it to the CloudFront distribution."
  value       = aws_acm_certificate_validation.site.certificate_arn
}

output "site_fqdn" {
  description = "Fully qualified name the certificate was issued for (e.g. app.example.com), so P9 reuses it instead of rebuilding the string."
  value       = "${var.site_hostname}.${var.domain_name}"
}
