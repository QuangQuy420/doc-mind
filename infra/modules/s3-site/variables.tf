variable "bucket_name" {
  description = "Full name of the site bucket (`docmind-<env>-site-<account_id>`). S3 bucket names are globally unique, so the account id is part of the name; no default, because the environment name belongs to the root module."
  type        = string
}

variable "site_fqdn" {
  description = "Fully qualified hostname the SPA is served on (e.g. app.example.com). It comes from the `dns` module, which owns the name — the alias record, the certificate and the Cognito callback URLs all read the same string so they can never drift."
  type        = string
}

variable "certificate_arn" {
  description = "ARN of a validated ACM certificate for `site_fqdn`. CloudFront reads certificates only from us-east-1, so this must be the us-east-1 one from the `dns` module."
  type        = string
}

variable "zone_id" {
  description = "Hosted zone the alias records for `site_fqdn` are created in."
  type        = string
}

variable "price_class" {
  description = "Which edge locations CloudFront serves from. `PriceClass_200` covers North America, Europe and Asia (including Singapore, the region this project runs in) and skips the most expensive South America / Oceania edges; `PriceClass_All` adds them, `PriceClass_100` is US + Europe only."
  type        = string
  default     = "PriceClass_200"
}
