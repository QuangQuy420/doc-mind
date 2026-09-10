# The SPA's origin: a fully private S3 bucket whose objects only CloudFront may
# read. The browser never talks to S3 — it talks to the distribution, which signs
# each origin request with SigV4 (see cloudfront.tf).
#
# Deliberately NOT an S3 website endpoint: that endpoint is plain HTTP only, is
# public by definition, and cannot be locked to one distribution. Its one perk —
# the built-in "error document" — is replaced here by CloudFront's
# `custom_error_response`.
#
# One concern per file: bucket.tf (the origin bucket) · cloudfront.tf (the
# distribution, its OAC and the bucket policy that trusts it) · dns.tf (the
# alias records).

resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name

  # dev only: `terraform destroy` fails on a bucket that still holds objects, and
  # this one always does (every deploy uploads a build). A production site bucket
  # must NOT have it — it turns an accidental destroy into silent data loss.
  force_destroy = true

  tags = {
    Name = var.bucket_name
  }
}

# Belt and braces next to the bucket policy: even if a future policy or ACL tried
# to grant `*`, S3 refuses to make the bucket public while all four are true.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 (AES256) is free and enough for a compiled front-end bundle: the files
# are public content served to any visitor, so the encryption here is about
# encryption-at-rest hygiene, not secrecy. SSE-KMS would add per-request cost —
# OAC would still work with it, which is one of the reasons it replaced OAI.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ACLs off entirely: ownership is decided by the bucket, not by whoever uploaded
# the object. It is the modern default and it removes the whole class of "the
# object is there but nobody can read it" bugs that per-object ACLs caused.
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
