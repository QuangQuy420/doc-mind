# The CDN in front of the bucket: TLS for the custom hostname, caching at the
# edge, and the SPA rewrite that makes client-side routes work.

locals {
  # Any stable string; it is only the join between the `origin` block and the
  # cache behaviour that targets it.
  origin_id = "s3-${var.bucket_name}"

  # AWS-managed cache policy `CachingOptimized`: cache key = the URL path only
  # (no cookies, no query string, no headers), TTLs 1 day / 1 year, and
  # `gzip`/`br` requested from the origin. The id is global and documented. Using
  # the managed policy instead of a hand-written one means one fewer resource and
  # the same behaviour AWS uses in its own SPA examples.
  cache_policy_caching_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

# Origin Access Control: CloudFront signs every request to S3 with SigV4 using a
# service principal, so the bucket can stay fully private. It replaces the legacy
# Origin Access Identity (a pseudo-user in the bucket policy), which could not
# sign requests and therefore could not read SSE-KMS objects or use anything but
# GET/HEAD.
resource "aws_cloudfront_origin_access_control" "site" {
  name        = var.bucket_name
  description = "SigV4 access from the DocMind SPA distribution to its private origin bucket"

  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled = true

  # IPv6 costs nothing and is why dns.tf creates an AAAA alias as well as an A.
  is_ipv6_enabled = true

  comment             = "docmind dev SPA (${var.site_fqdn})"
  aliases             = [var.site_fqdn]
  default_root_object = "index.html"
  price_class         = var.price_class

  origin {
    origin_id = local.origin_id

    # The *regional* domain name (`<bucket>.s3.<region>.amazonaws.com`), not the
    # global one: the global name can answer with an HTTP redirect right after
    # the bucket is created, which OAC-signed requests cannot follow.
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id = local.origin_id

    # Plain HTTP is answered with a 301 to HTTPS instead of being refused, so a
    # typed `app.example.com` still reaches the site.
    viewer_protocol_policy = "redirect-to-https"

    # A static site is read-only. OPTIONS is allowed (but not cached) only so
    # this block needs no edit if the origin ever serves CORS; the bucket has no
    # CORS configuration today, so nothing sends a preflight here.
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    # Brotli/gzip at the edge for the JS bundle; S3 stores it uncompressed.
    compress = true

    cache_policy_id = local.cache_policy_caching_optimized
  }

  # The SPA rewrite. React Router owns `/documents`, but S3 has no such key, so
  # a deep link or a refresh would fail. Both codes are mapped on purpose:
  # a bucket read through OAC answers **403 AccessDenied**, not 404, for a
  # missing key — the policy below grants `GetObject` but never `ListBucket`, so
  # S3 refuses to admit whether the key exists. Returning `index.html` with a 200
  # lets the router resolve the path in the browser.
  #
  # `error_caching_min_ttl = 0` keeps CloudFront from caching the error: without
  # it a 404 recorded during a deploy would be served for 10 seconds after the
  # object is really there.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  # Required block. No geo blocking: this is a personal site, not a licensed
  # catalogue.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Same Name tag as the bucket; everything else rides the provider default_tags.
  tags = {
    Name = var.bucket_name
  }

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn

    # SNI is free; the alternative (a dedicated IP per distribution) costs ~600
    # USD/month and only exists for clients too old to send SNI.
    ssl_support_method = "sni-only"

    # Floor for the TLS handshake with the *viewer*. TLSv1.2_2021 also drops the
    # weak ciphers of the older 1.2 policies; nothing since ~2015 needs less.
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# The only thing allowed to read the bucket: this distribution, identified by its
# ARN. `AWS:SourceArn` is what makes the grant specific — the service principal
# alone would let *any* CloudFront distribution in *any* account read the objects
# (the classic confused-deputy hole).
#
# Only `s3:GetObject`, deliberately no `s3:ListBucket`: CloudFront never needs to
# enumerate the bucket, and without it S3 answers 403 (not 404) for a missing
# key — which is exactly what the 403 rewrite above is built on.
data "aws_iam_policy_document" "site_oac_read" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalRead"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

# A separate resource, not an inline policy on the bucket: the policy needs the
# distribution ARN and the distribution needs the bucket's domain name, so
# folding the policy into `aws_s3_bucket` would be a dependency cycle. Split in
# three, the graph is bucket -> distribution -> policy.
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_oac_read.json

  # A bucket policy can lock the bucket out; block public access first.
  depends_on = [aws_s3_bucket_public_access_block.site]
}
