output "bucket_name" {
  description = "Name of the site bucket. The deploy script syncs the built SPA into it (`aws s3 sync dist/ s3://<name>`)."
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "Id of the CloudFront distribution, for `aws cloudfront create-invalidation --distribution-id <id>` after a deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_domain_name" {
  description = "The distribution's own hostname (`d111111abcdef8.cloudfront.net`). The alias records point at it; useful to test the distribution before DNS has propagated."
  value       = aws_cloudfront_distribution.site.domain_name
}

# Built from the input rather than the record, so the value is known at plan time
# and reads as the same string the certificate and the Cognito callbacks use.
output "site_url" {
  description = "Base URL of the SPA, without a trailing slash (e.g. https://app.example.com). The SPA's `VITE_REDIRECT_URI` is this plus `/` — Cognito matches callback URLs byte for byte."
  value       = "https://${var.site_fqdn}"
}
