variable "name" {
  description = "Name of the user pool (`docmind-<env>-users`). The pool name is cosmetic — the pool id is what tokens and IAM refer to — so unlike the other modules it carries a default."
  type        = string
  default     = "docmind-dev-users"
}

variable "aws_region" {
  description = "Region the pool lives in. Only used to build the issuer and Hosted UI URLs, which are region-scoped strings, not resource arguments."
  type        = string
}

variable "callback_urls" {
  description = "Exact redirect URIs the app client may send the user back to after login. Cognito matches them byte for byte, trailing slash included."
  type        = list(string)
}

variable "logout_urls" {
  description = "Exact URIs the Hosted UI may redirect to after `/logout`. Same byte-for-byte matching as the callbacks."
  type        = list(string)
}
