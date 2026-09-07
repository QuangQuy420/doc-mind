# Cognito prefix domains share one global namespace per region, so
# `docmind-dev` alone would collide with anyone else's. Three random bytes (six
# hex characters) make that practically impossible. `random_id` is generated
# once and kept in state; changing the prefix REPLACES the domain, and the
# Hosted UI URL — which is baked into the SPA's build — changes with it.
resource "random_id" "domain_suffix" {
  byte_length = 3
}

resource "aws_cognito_user_pool_domain" "this" {
  # The prefix is the environment name, not `var.name`: it must stay short,
  # lowercase and hyphen-only, and it is a URL, not the pool's display name.
  domain       = "docmind-dev-${random_id.domain_suffix.hex}"
  user_pool_id = aws_cognito_user_pool.this.id

  # 1 = the classic Hosted UI, 2 = the new managed login (branding designer,
  # Essentials tier only). Pinned to 1 because the classic pages are the ones the
  # `/login?client_id=…&response_type=code` URL in the runbook drives, and
  # switching versions changes the login page under the SPA without warning.
  managed_login_version = 1
}
