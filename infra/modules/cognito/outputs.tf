output "user_pool_id" {
  description = "Id of the user pool (e.g. ap-southeast-1_ab12CD34). It is the last path segment of the issuer and what the AWS CLI needs for admin calls."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN of the pool, so IAM policies can be scoped to it instead of `*` when a later phase calls the Cognito admin APIs."
  value       = aws_cognito_user_pool.this.arn
}

output "client_id" {
  description = "Id of the SPA app client. The SPA sends it in the authorize URL and the API checks it on every access token, so a token from another client of the same pool is rejected."
  value       = aws_cognito_user_pool_client.spa.id
}

# Built as a string rather than read from an attribute: the issuer is a
# documented, region-scoped URL shape and the provider exposes no field for it.
output "issuer" {
  description = "OIDC issuer URL of the pool. P7 verifies the `iss` claim against it and fetches the signing keys from `<issuer>/.well-known/jwks.json`."
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

output "hosted_ui_domain" {
  description = "Base URL of the Hosted UI, e.g. https://docmind-dev-ab12cd.auth.ap-southeast-1.amazoncognito.com. The login and logout pages hang off it."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.aws_region}.amazoncognito.com"
}
