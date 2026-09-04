# infra/bootstrap — remote state, applied once

This stack creates the two things every other stack needs before it can store
state remotely:

| Resource | Name | Why |
|---|---|---|
| S3 bucket | `docmind-tfstate-<account_id>` | Holds `terraform.tfstate` for each env. Versioned, so a broken state can be rolled back. |
| DynamoDB table | `docmind-tflock` | Classic state lock (conditional write on `LockID`), so two applies cannot run at once. |

## Why local state here

A stack cannot store its state in a bucket it has not created yet — the classic
chicken-and-egg. So `infra/bootstrap` keeps `terraform.tfstate` **on your
machine** (git-ignored). It is applied once and then left alone.

## Apply it (owner, once)

```bash
export AWS_PROFILE=docmind-dev
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply
```

Note the outputs: `state_bucket`, `lock_table`, `account_id`. The account id goes
into `infra/envs/dev/backend.tf`.

## Never delete this

`terraform destroy` here would delete the bucket holding the state of every other
stack — Terraform would then think nothing exists and try to recreate the whole
account. `force_destroy = false` makes S3 refuse to delete a non-empty bucket,
which is the guardrail. If you ever really must start over, empty and delete the
bucket by hand, on purpose.

Losing the local `terraform.tfstate` in this folder is survivable: the bucket and
table still exist, and you can `terraform import` them back.

## Cost

0 USD. A few KB in S3 and a handful of on-demand DynamoDB writes are far inside
the free usage tiers.
