# The private registry the EC2 host (P8) and later the ECS tasks (Phase 4) pull
# the API image from. One repository per image, not per environment: the tag
# carries the version, the repository name carries the identity.

resource "aws_ecr_repository" "this" {
  name = var.name

  # MUTABLE lets `:latest` be re-pushed, which is exactly the dev loop here
  # (build -> push -> replace the instance). IMMUTABLE is the production answer:
  # a tag then always means one digest, so a rollback is unambiguous — but it
  # forces a new tag on every build, which needs a CI pipeline to be pleasant.
  image_tag_mutability = "MUTABLE"

  # Free basic scanning: on every push AWS matches the installed OS packages
  # against the CVE database. It finds nothing about the Python dependencies —
  # that is what `pip-audit`/Dependabot are for — but it costs nothing.
  image_scanning_configuration {
    scan_on_push = true
  }

  # dev only: without this, destroying the repository fails while it still holds
  # images, which turns every teardown into a manual delete. A production
  # repository must NOT have it — it makes an accidental destroy silent.
  force_delete = true

  tags = {
    Name = var.name
  }
}

# Untagged and superseded layers are billed like any other storage. The policy
# runs on AWS's side (no cron, no Lambda) and expires everything past the newest
# 10 images.
#
# `tagStatus = "any"` counts tagged and untagged images together: with a mutable
# `:latest`, every push leaves the previous image untagged, so a rule scoped to
# untagged images only would keep growing the tagged set forever.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the 10 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
