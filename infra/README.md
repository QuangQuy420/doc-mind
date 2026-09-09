# infra/ — all AWS resources, Terraform only

Nothing in this project is created by clicking in the console. If something has
to be clicked once (Bedrock model access, a domain registration), it is written
down as an owner step, not hidden.

```
infra/
├── bootstrap/     # state bucket + lock table. Local state. Applied once, never destroyed.
├── modules/       # reusable child modules (vpc, dns, rds, ...). Added per phase.
└── envs/dev/      # the root module you actually apply. Remote state in the bootstrap bucket.
```

**Root module vs child module:** the root module is the directory you run
`terraform apply` in (`envs/dev`). Child modules under `modules/` own a group of
resources, take typed inputs and expose outputs; the root wires them together and
holds the environment's variables. Splitting *state* (a separate root module)
is about blast radius and ownership — not something a solo dev needs yet, apart
from `bootstrap`.

## First run (owner, in order)

```bash
export AWS_PROFILE=docmind-dev

# 1. Create the remote state backend. Once, ever.
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply        # note the `account_id` output

# 2. Put that account id into infra/envs/dev/backend.tf (replace <ACCOUNT_ID>).
#    Backend blocks take no variables, so this is a literal edit.

# 3. Fill in your settings.
cp infra/envs/dev/dev.auto.tfvars.example infra/envs/dev/dev.auto.tfvars
$EDITOR infra/envs/dev/dev.auto.tfvars        # set budget_email

# 4. Apply the environment.
terraform -chdir=infra/envs/dev init          # configures the S3 backend
terraform -chdir=infra/envs/dev plan          # read this line by line
terraform -chdir=infra/envs/dev apply
```

Everyday loop afterwards: `plan` → read it → `apply`. Before committing:
`terraform fmt -recursive infra/` and `pre-commit run --files <changed files>`.

## Remote state and locking

State is the map from Terraform config to real AWS resource ids. It lives in
`s3://docmind-tfstate-<account_id>/envs/dev/terraform.tfstate`, versioned and
encrypted, because two machines (or two terminals) applying against different
local copies would silently create duplicates or orphan resources.

Locking stops two applies running at once. Two mechanisms are configured, on
purpose:

| Mechanism | How | Status |
|---|---|---|
| `use_lockfile = true` | Conditional write on an `.tflock` object next to the state file | Current, supported path |
| `dynamodb_table = "docmind-tflock"` | Conditional `PutItem` on `LockID` in DynamoDB | The classic pattern; deprecated in the S3 backend since Terraform 1.11 |

Same idea — an atomic "create only if absent" — with one service fewer. Terraform
1.11+ prints a deprecation warning for `dynamodb_table`; that is expected. To see
a lock in action: start an `apply` in one terminal, leave the confirmation prompt
open, and run `plan` in a second — it fails with a state lock error.

## How to read a plan

`plan` reads the real AWS API, compares it with state, and prints the diff it
would execute. `apply` executes that diff. Read every symbol:

| Symbol | Meaning | Watch for |
|---|---|---|
| `+` | create | Is this billable? Is it in the right region? |
| `-` | destroy | Never on data (bucket, RDS, DynamoDB) unless you meant it |
| `~` | update in place | Safe |
| `-/+` | **replace** — destroy then create | The dangerous one. The plan names the attribute that forces it ("forces replacement"). |
| `<=` | read a data source | No change |

The summary line (`Plan: X to add, Y to change, Z to destroy`) is the thing to
check before typing `yes`. `(known after apply)` just means the value comes from
AWS at creation time. If a plan surprises you, stop and find out why — a drifted
resource usually means someone (you) clicked something in the console.

## Cost toggles

Anything billed while idle sits behind a `bool` variable defaulting to `false`
(`count = var.enable_x ? 1 : 0`). Flip it on while testing, flip it back after.

| Variable | Resource | Phase | Approx. cost while on |
|---|---|---|---|
| `enable_nat` | NAT Gateway | 3 | ~32 USD/month + per-GB data processing |
| `enable_rds` | RDS PostgreSQL `db.t4g.micro` | 5 | ~12–15 USD/month outside free tier |
| `enable_ec2` | EC2 app instance | 8 | ~12 USD/month for `t4g.small` 24/7 (+3.6 USD/month for the EIP while stopped) |
| `enable_cost_allocation_tag` | `aws_ce_cost_allocation_tag` `Project` | 2 | 0 USD (needs the tag to appear in billing first, ~24h) |

One accepted always-on exception: the Route 53 hosted zone (`dns`, Phase 4) at
0.50 USD/month. It gets no toggle because destroying and recreating it hands out
four new name servers, which would break the registrar delegation every time the
toggle is flipped.

The 20 USD/month budget (`envs/dev/budget.tf`) alerts by email at 50 %, 80 % and
100 % of *actual* spend. Budgets alert; they do not stop anything.

## DNS delegation

The domain is bought at an external registrar, but the *records* live in a Route
53 hosted zone managed here. The registrar only has to be told, once, which name
servers to point at. Until that is done nothing in the zone resolves — and ACM's
DNS validation blocks — so the first apply is deliberately targeted at the zone
alone.

```bash
# 1. Set the domain (bare, lowercase, no scheme, no trailing dot).
$EDITOR infra/envs/dev/dev.auto.tfvars        # domain_name = "your-domain.com"

# 2. Create ONLY the hosted zone, then read its four name servers.
terraform -chdir=infra/envs/dev apply -target=module.dns.aws_route53_zone.this
terraform -chdir=infra/envs/dev output name_servers

# 3. Replace the registrar's name servers with those four, then wait until the
#    TLD servers hand them out. `+trace` asks from the root down, so a stale
#    cached answer cannot fool you. Minutes to hours.
dig NS your-domain.com +trace

# 4. Full apply. ACM validates within a few minutes once DNS resolves.
terraform -chdir=infra/envs/dev apply
```

A targeted apply prints `Warning: Applied changes may not be reflected in the
outputs` — with `-target`, Terraform may skip refreshing the output values. If
`terraform output name_servers` comes back empty, read them straight from state:

```bash
terraform -chdir=infra/envs/dev state show module.dns.aws_route53_zone.this
```

If step 4 fails with a validation timeout (ACM gives up after 75 minutes), the
delegation was not live yet: check `dig` again and re-run `apply`.

**Recreating the zone rotates its name servers.** A destroyed and re-applied
zone (the "from zero" test, or any replacement of the resource) gets four new
ones while the registrar still points at the old set, so delegation silently
breaks. There is no `prevent_destroy` guarding it on purpose — repeat steps 2–4
every time the zone is recreated.

## Module boundaries

One module per bounded group of resources. Each gets typed, described
`variables.tf` and an `outputs.tf`; the root module never hard-codes an ARN it
could read from an output.

| Module | Phase | Owns |
|---|---|---|
| `vpc` | 3 | VPC, 2 public + 2 private subnets across 2 AZs, IGW and route tables, S3/DynamoDB gateway endpoints, optional NAT, the app and RDS security groups |
| `dns` | 4 | Route 53 hosted zone and records, the ACM certificate (us-east-1 for CloudFront) and its DNS validation |
| `rds` | 5 | PostgreSQL instance, subnet group, `random_password`, and the two SSM parameters (SecureString password, plain host) |
| `dynamodb` | 5 | The `documents` table, its `status-createdAt-index` GSI, streams and TTL |
| `cognito` | 6 | User pool, password/email policy, the public PKCE app client, the hosted UI domain |
| `ecr` | 8 | Private repository for the API image, scan-on-push, the keep-last-10 lifecycle policy |
| `ec2-app` | 8 | App instance and its instance profile, user data, SSM Session Manager access, ECR pull permissions, the Elastic IP and the `api` A record |
| `s3-site` | 9 | Private SPA bucket, CloudFront distribution and origin access control, cache behaviours |

## The API image and the app host (Phase 8)

The repository (`module.ecr`) and the log group are always created and cost
nothing while empty. The host itself (`module.ec2_app`) is behind `enable_ec2`.
Order matters: **push an image before flipping the toggle on**, or the instance
spends its first ten minutes retrying the pull.

```bash
export AWS_PROFILE=docmind-dev
REGISTRY=$(terraform -chdir=infra/envs/dev output -raw ecr_repository_url)

# 1. Log in to the private registry. The token lasts 12 hours.
aws ecr get-login-password --region ap-southeast-1 \
  | docker login --username AWS --password-stdin "${REGISTRY%%/*}"

# 2. Build for arm64 and push. The build host is x86 (WSL2) and the instance is
#    Graviton, so `buildx` cross-builds — a plain `docker build` would produce an
#    image the box cannot run ("exec format error"). Context is the REPO ROOT.
docker buildx build --platform linux/arm64 -f apps/api/Dockerfile \
  -t "$REGISTRY:latest" --push .

# 3. Start the database first (the boot script runs the migration), then the host.
aws rds start-db-instance --db-instance-identifier docmind-dev-postgres
$EDITOR infra/envs/dev/dev.auto.tfvars        # enable_ec2 = true
terraform -chdir=infra/envs/dev apply         # ~3 minutes until the API answers
```

A new image is picked up by replacing the instance, not by re-applying — the
tag is mutable, so Terraform sees no change:

```bash
terraform -chdir=infra/envs/dev apply -replace=module.ec2_app[0].aws_instance.this
```

The same command is how a new Amazon Linux AMI is adopted: the AMI id comes from
the "latest AL2023" SSM parameter but is `ignore_changes`, so AWS publishing a
build never replaces the instance behind your back.

### Shell access: Session Manager, not SSH

There is no port 22 rule and no key pair anywhere in this project. Shell access
goes through SSM, which needs no inbound rule, authenticates with IAM and logs
the session.

```bash
# One-time on the workstation: the AWS CLI shells out to a separate binary.
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
session-manager-plugin --version              # must print a version

aws ssm start-session --target "$(terraform -chdir=infra/envs/dev output -raw ec2_instance_id)"

# Inside the session — what to look at when the API does not answer:
sudo docker ps                                # expect `api` and `caddy`, both Up
sudo cat /var/log/cloud-init-output.log       # the whole boot script's output
sudo docker logs caddy                        # certificate / ACME problems
```

`cloud-init-output.log` is the one that matters: the boot script runs with
`set -euo pipefail`, so a failed migration stops it and *neither* container
starts. Fix the cause, then replace the instance with the `-replace` command
above — nothing retries on its own.

### Logs

Both containers write to the `/docmind/api` log group (7-day retention) through
the Docker `awslogs` driver, in streams named `api-<instance-id>` and
`caddy-<instance-id>`. The saved Logs Insights query
`docmind-dev-api-p95-per-route` reports p95 latency and request count per path;
open it from CloudWatch → Logs Insights → Queries.

## Teardown between sessions

The environment is designed to cost nothing while idle, but only if the toggles
are actually back off. Run this at the end of every session that flipped one on:

```bash
# 1. Put every enable_* back to false in infra/envs/dev/dev.auto.tfvars
$EDITOR infra/envs/dev/dev.auto.tfvars

# 2. Destroy what the toggles created — read the plan, it should only remove.
terraform -chdir=infra/envs/dev apply

# 3. Prove nothing billable is left running.
terraform -chdir=infra/envs/dev plan     # "No changes."
```

A `plan` that still shows changes means a toggle was missed or something was
clicked in the console. `No changes` is the only acceptable end state.

**`enable_rds` is the exception to step 1.** Once the database exists, leave
`enable_rds = true` in `dev.auto.tfvars` forever: flipping it back and applying
destroys the instance, and `skip_final_snapshot = true` means the data goes with
it. Stop the instance instead — a stopped instance is still in state, so `plan`
keeps saying `No changes`:

```bash
# End of session: stop it (no compute charge while stopped).
aws rds stop-db-instance --db-instance-identifier docmind-dev-postgres

# Next session: start it BEFORE any apply that modifies the instance —
# an apply against a stopped instance fails.
aws rds start-db-instance --db-instance-identifier docmind-dev-postgres
```

Two things to know: AWS starts a stopped instance again by itself after 7 days
(so it has to be stopped again), and a stopped instance still bills its storage,
about 2 USD/month for 20 GB of gp3.

`terraform destroy` is the bigger hammer and is **not** the routine here: it
removes the whole dev environment — VPC, budget and every later module — which
is far more than this needs, and everything it would remove is free anyway except
the hosted zone — and destroying that costs a re-delegation at the registrar
(see "DNS delegation"), not money. The state bucket and lock table are untouched
either way; they belong to `infra/bootstrap`. Toggle off, don't destroy.

**`enable_ec2` is the opposite case to `enable_rds`: flip it off.** Stopping the
instance only saves the compute. Two things keep billing on a stopped box:

| Left behind by a stop | Cost |
|---|---|
| Elastic IP, now unattached to a *running* instance | ~3.6 USD/month |
| 20 GB gp3 root volume | ~1.6 USD/month |

```bash
# Cheap pause, keeps the IP, the certificate and the host: ~5 USD/month.
aws ec2 stop-instances --instance-ids "$(terraform -chdir=infra/envs/dev output -raw ec2_instance_id)"

# Free: releases the EIP and the volume too. The `api` A record disappears with
# the module, so DNS never points at nothing. Next session gets a new IP and a
# freshly issued certificate — Let's Encrypt allows 5 duplicates per week, so
# this is not a thing to do ten times a day.
$EDITOR infra/envs/dev/dev.auto.tfvars        # enable_ec2 = false
terraform -chdir=infra/envs/dev apply
```

Nothing in ECR is toggled: the images stay (~0.10 USD/GB/month, at most 10 of
them) so the next session skips the push.

Currently billable behind a toggle: `enable_nat` (Phase 3), `enable_rds`
(Phase 5, stopped rather than toggled off — see above) and `enable_ec2`
(Phase 8, toggled off — see just above). The one always-on cost, with no
toggle, is the 0.50 USD/month hosted zone.

## Checks

```bash
terraform fmt -check -recursive infra/
terraform -chdir=infra/bootstrap init -backend=false && terraform -chdir=infra/bootstrap validate
terraform -chdir=infra/envs/dev init -backend=false && terraform -chdir=infra/envs/dev validate
tflint --init && tflint --recursive        # run from infra/
```

`init -backend=false` downloads the providers without touching AWS, which is what
makes `validate` runnable offline. The generated `.terraform.lock.hcl` files are
committed (they pin provider checksums); `.terraform/` directories are not.
