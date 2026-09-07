# DNS for one environment: the public hosted zone for the domain plus the
# CloudFront certificate for the SPA and its DNS validation. Later phases add
# the records that point at real things (P8 the `api` A record, P9 the `app`
# alias) — this module only creates the zone they need to exist in.
#
# One concern per file: main.tf (zone) · acm.tf (certificate + validation).

# The hosted zone is only a container for records: it changes nothing until the
# registrar is told to delegate to its four name servers (see the `name_servers`
# output and infra/README.md "DNS delegation"). Deliberately not behind a cost
# toggle — 0.50 USD/month — because destroying and recreating it hands out new
# name servers and breaks the delegation every time.
resource "aws_route53_zone" "this" {
  name = var.domain_name

  comment = "docmind dev - delegate at the registrar to the name_servers output"
}
