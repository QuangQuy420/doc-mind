# The app client the browser SPA uses. One client per application, because the
# client id is what scopes the token: the API checks `client_id` on every access
# token, so a token minted for another client of the same pool is rejected.
resource "aws_cognito_user_pool_client" "spa" {
  name         = "${var.name}-spa"
  user_pool_id = aws_cognito_user_pool.this.id

  # No secret: anything shipped to a browser is public by definition. A public
  # client proves it started the flow with PKCE (it sends a hashed verifier up
  # front and the plain one when redeeming the code) instead of with a secret.
  generate_secret = false

  # Authorization code only. The implicit flow would put tokens in the URL
  # fragment — in history, in referrers, in logs — and `client_credentials` is
  # for machine-to-machine clients with a secret, which this is not.
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  # Cognito matches these byte for byte against the `redirect_uri` the SPA sends.
  # A missing trailing slash is the classic "redirect_mismatch" hour lost.
  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Only the pool's own users; no Google/Facebook/SAML federation in this project.
  supported_identity_providers = ["COGNITO"]

  # SRP never sends the password over the wire and is what the SPA uses; refresh
  # keeps the session alive. ALLOW_USER_PASSWORD_AUTH sends the plain password to
  # Cognito over TLS and exists only so the owner can grab a test token from the
  # CLI in P7 — remove it in Phase 4 hardening.
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]

  # Returns the same generic error whether or not the account exists, so the
  # login form cannot be used to enumerate which emails are registered.
  prevent_user_existence_errors = "ENABLED"

  # Short-lived access/id tokens (60 minutes) with a 30-day refresh token: a
  # stolen access token expires on its own, and revocation only has to work on
  # the refresh token. Cognito's minimum is 5 minutes, its maximum 24 hours.
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  # The numbers above are unitless until this block says what they mean; the
  # provider defaults to hours, which would quietly make them 60-hour tokens.
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
