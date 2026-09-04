terraform {
  # 1.10 is the first release with `use_lockfile` (S3-native state locking).
  # `< 2.0` guards against a future breaking major.
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
