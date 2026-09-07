variable "name" {
  description = "Full table name (`docmind-<env>-documents`). No default: the environment name belongs to the root module, not to a reusable module."
  type        = string
}
