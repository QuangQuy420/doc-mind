# Bootstrap stack: the two resources that must exist BEFORE any other stack can
# use a remote backend. Applied once, with local state, and never destroyed.

data "aws_caller_identity" "current" {}

# --- Remote state bucket ------------------------------------------------------

# The account id keeps the name globally unique without a random suffix, so the
# name is reproducible and can be typed into backend.tf by hand.
resource "aws_s3_bucket" "tfstate" {
  bucket = "docmind-tfstate-${data.aws_caller_identity.current.account_id}"

  # Deleting this bucket would delete the state of every other stack.
  force_destroy = false
}

# State history: every apply writes a new version, so a corrupted or truncated
# state file can be rolled back object-version by object-version.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) is free and enough here; state holds resource ids, not secrets
# we own the keys for. KMS would add per-request cost and a key policy to manage.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Old state versions are history, not forever: keep 90 days of rollback room and
# let S3 clean up the rest.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    # Empty filter = the rule applies to every object in the bucket.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# Refuse plaintext HTTP. `s3:*` is acceptable here because this is a Deny: a
# wildcard on a deny only ever removes permissions, never grants them.
data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json

  # A bucket policy can lock the bucket out; block public access first.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# --- State lock table ---------------------------------------------------------

# The classic Terraform lock: a conditional PutItem on `LockID` fails if another
# apply already holds the lock. Deprecated in the S3 backend since Terraform
# 1.11 (see envs/dev/backend.tf) but kept here to learn the pattern; it costs
# nothing on-demand because only a handful of writes ever hit it.
resource "aws_dynamodb_table" "tflock" {
  name         = "docmind-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
