variable "domain_name" {
  description = "Bare root domain the hosted zone is created for (e.g. example.com). The registrar must delegate to this zone's name servers."
  type        = string
}

variable "site_hostname" {
  description = "Hostname of the SPA under the root domain. The ACM certificate is issued for `<site_hostname>.<domain_name>`."
  type        = string
  default     = "app"
}
