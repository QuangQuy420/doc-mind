# Root module for the dev environment.
#
# Child modules are wired here as each phase lands — see .plans/00-overview.md
# for the roadmap and infra/README.md for the module boundaries table
# (vpc, dns, rds, dynamodb, cognito, ec2-app, s3-site).
#
# Empty on purpose right now: the only resources this environment owns are the
# budget (budget.tf) and, once switched on, the cost allocation tag.

data "aws_caller_identity" "current" {}
