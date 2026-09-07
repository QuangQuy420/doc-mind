# The identity provider for the app: a Cognito User Pool that owns the users,
# their passwords and the tokens the API verifies. Deliberately NOT an Identity
# Pool — that one swaps a token for temporary AWS credentials, which only makes
# sense when the browser calls AWS directly. Here the browser only calls our
# API, and the API has its own instance role.
#
# One concern per file: main.tf (the pool) · client.tf (the SPA app client) ·
# domain.tf (the Hosted UI domain).

resource "aws_cognito_user_pool" "this" {
  name = var.name

  # Tiers, cheapest first: Lite (classic feature set, 50k free MAU), Essentials
  # (10k free MAU, adds managed login and passwordless), Plus (paid threat
  # protection). Essentials is the default for new pools and free at this scale;
  # it is pinned so a provider default change never silently moves the bill.
  user_pool_tier = "ESSENTIALS"

  # Email *is* the username: there is no separate handle to remember, and it
  # cannot be changed after the pool is created.
  username_attributes = ["email"]

  # Cognito sends the confirmation code itself and flips the account to
  # CONFIRMED when it is entered — no verification endpoint of our own.
  auto_verified_attributes = ["email"]

  # 12 characters with all four classes is stricter than the Cognito default (8,
  # all four). The cost of a long password is paid once by a human; the cost of a
  # short one is paid forever by anyone brute-forcing the pool.
  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # "Forgot password" is allowed over the verified email only. Leaving the
  # default (email *or* phone) would open a second recovery channel that this
  # pool never verifies.
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # COGNITO_DEFAULT is the shared AWS sender: free, no SES setup, and capped at
  # ~50 emails/day from a no-reply@verificationemail.com address. Enough for a
  # dev pool with one user; a real product moves to `DEVELOPER` + SES so the mail
  # comes from its own domain and is not rate limited.
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Self sign-up stays open for dev: anyone who finds the Hosted UI URL can
  # register. Accepted because the pool holds nothing but test accounts and the
  # API only trusts tokens minted for its own client id. Flip this to `true` to
  # make the pool invite-only.
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # A dev pool is meant to be disposable; protection would block
  # `terraform destroy`. Note that destroying the pool deletes every user in it.
  deletion_protection = "INACTIVE"

  # The email attribute is declared explicitly so the pool is not relying on the
  # implicit standard attribute. Any later change here FORCES REPLACEMENT of the
  # pool (every user lost), so it is worth getting right once and then leaving
  # alone. `string_attribute_constraints` is spelled out because the API returns
  # the 0-2048 defaults for it: omitting the block leaves a perpetual diff.
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  tags = {
    Name = var.name
  }
}
