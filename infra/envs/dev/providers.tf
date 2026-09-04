# Default provider: everything lives in the app region unless it cannot.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "docmind"
      Env       = "dev"
      ManagedBy = "terraform"
    }
  }
}

# CloudFront only accepts ACM certificates issued in us-east-1, so a second
# provider aliased to that region is wired now and used from Phase 4 onwards.
# An alias is a second configuration of the same provider; resources opt in with
# `provider = aws.us_east_1`.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "docmind"
      Env       = "dev"
      ManagedBy = "terraform"
    }
  }
}
