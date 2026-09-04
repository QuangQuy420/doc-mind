provider "aws" {
  region = var.aws_region

  # Every resource in this stack inherits these tags, so cost allocation and
  # Cost Explorer filters work without tagging each resource by hand.
  default_tags {
    tags = {
      Project   = "docmind"
      Env       = "dev"
      ManagedBy = "terraform"
    }
  }
}
