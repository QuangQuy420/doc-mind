# Terraform + provider version pins for the bootstrap stack.
# Kept identical to envs/dev so both stacks behave the same way.

terraform {
  # 1.10 is the first release with `use_lockfile` (S3-native state locking),
  # which envs/dev relies on. `< 2.0` guards against a future breaking major.
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend block on purpose: this stack CREATES the remote state backend,
  # so it keeps its own state on the owner's machine (git-ignored).
}
