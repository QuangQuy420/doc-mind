# AWS Budgets are account-wide, not per-environment, so this one is named
# `docmind-monthly` rather than `docmind-dev-...`. Budgets alert; they never stop
# spend. Cost budgets themselves are free — only budget *actions* are billed
# after the first two, and we use none.
resource "aws_budgets_budget" "monthly" {
  name         = "docmind-monthly"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # ACTUAL (not FORECASTED) so an alert always means money already spent.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

# Cost Explorer can only group by a tag after that tag has been activated as a
# cost allocation tag, and AWS only offers a tag key once it has been seen on a
# billed resource (roughly a day after the first one). So this stays behind a
# toggle: apply once with it false, wait a day, then set
# enable_cost_allocation_tag = true and apply again.
resource "aws_ce_cost_allocation_tag" "project" {
  count = var.enable_cost_allocation_tag ? 1 : 0

  tag_key = "Project"
  status  = "Active"
}
