# CloudFront reads certificates only from us-east-1, whatever region the rest of
# the stack lives in, so this certificate is pinned to the aliased provider the
# root passes in. ACM certificates are free; only the validation records cost
# (nothing, they live in the zone above).
resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name       = "${var.site_hostname}.${var.domain_name}"
  validation_method = "DNS"

  # If the domain list ever changes, ACM replaces the certificate. Creating the
  # new one before destroying the old avoids a window with no valid certificate.
  lifecycle {
    create_before_destroy = true
  }
}

# ACM asks for one CNAME per domain on the certificate to prove we control it.
# `domain_validation_options` is a set, so it is keyed by domain name to give
# each record a stable address in state. Today that is exactly one record; the
# for_each keeps working if a SAN is added later.
#
# `allow_overwrite` matters because ACM reuses the same validation record name
# for a re-issued certificate: without it a replacement would fail on "record
# already exists". TTL 60 keeps a fix propagating quickly during the first run.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Not a real AWS resource: it makes Terraform wait until ACM has seen the CNAMEs
# and moved the certificate to Issued. Anything depending on the certificate ARN
# should read it from here, not from the certificate itself, so it is never
# handed an ARN that CloudFront would reject as not-yet-validated.
#
# This blocks (up to 75 minutes) while the registrar still points elsewhere —
# hence the targeted zone-first apply in infra/README.md "DNS delegation".
resource "aws_acm_certificate_validation" "site" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
