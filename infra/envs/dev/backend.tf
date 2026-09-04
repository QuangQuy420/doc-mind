terraform {
  backend "s3" {
    # Backend blocks cannot use variables or locals — Terraform reads them before
    # it evaluates any expression. So the bucket name is a literal:
    # The account id is the `account_id` output of infra/bootstrap (set once by
    # the owner, then `terraform init`).
    # (The alternative is partial configuration:
    #  `terraform init -backend-config=bucket=...`, one file per env. Noted for
    #  the interview; a literal is simpler for a single dev environment.)
    bucket = "docmind-tfstate-123131744030"

    # One key per environment inside the same bucket keeps envs isolated.
    key    = "envs/dev/terraform.tfstate"
    region = "ap-southeast-1"

    # Current locking: a conditional write on an `.tflock` object next to the
    # state file. No extra service required.
    use_lockfile = true

    # Classic locking: a conditional PutItem on the DynamoDB table created by
    # infra/bootstrap. Deprecated since Terraform 1.11 in favour of
    # `use_lockfile`, and kept here on purpose to learn the original pattern —
    # both may be set at once. If a future Terraform removes the argument, delete
    # this line; `use_lockfile` keeps locking working.
    dynamodb_table = "docmind-tflock"

    encrypt = true
  }
}
