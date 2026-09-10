# `app.<domain>` -> the distribution. An *alias* record, not a CNAME: Route 53
# resolves it to the distribution's current edge IPs, it is free to query, and —
# unlike a CNAME — it is legal at a zone apex, which matters the day the site
# moves to the bare domain.
#
# Two records because the distribution has `is_ipv6_enabled = true`: A for IPv4,
# AAAA for IPv6. A client on an IPv6-only network gets nothing without the AAAA.
# `for_each` over the two types keeps the alias block written once.
resource "aws_route53_record" "site" {
  for_each = toset(["A", "AAAA"])

  zone_id = var.zone_id
  name    = var.site_fqdn
  type    = each.key

  alias {
    name    = aws_cloudfront_distribution.site.domain_name
    zone_id = aws_cloudfront_distribution.site.hosted_zone_id

    # Health checking is for weighted/failover record sets with a second target
    # to fail over to. There is one distribution, so an unhealthy answer here
    # would only mean "return nothing at all".
    evaluate_target_health = false
  }
}
