# One EC2 host running the API image behind Caddy, plus everything that makes it
# reachable: an Elastic IP and the `api.<domain>` record.
#
# Why a single instance and not ECS/ALB yet: this phase is about the primitives
# (AMI, user data, instance profile, IMDSv2, log driver). Phase 4 moves the same
# container to Fargate behind an ALB, which is where health checks, rolling
# deploys and ACM belong.
#
# One concern per file: main.tf (instance, EIP, DNS) · iam.tf (role and profile)
# · user_data.sh.tftpl (what boots inside the box).

# The current Amazon Linux 2023 arm64 AMI id, published by AWS as a public SSM
# parameter. Hard-coding an AMI id pins the region *and* rots; this always
# resolves to the newest build for whatever region the provider points at.
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

locals {
  # `templatefile` rejects a null interpolation value, so the database inputs
  # fall back to empty strings while `rds_enabled = false`. Nothing reads them
  # then: the whole block that uses them sits behind `%{ if rds_enabled }`.
  db_password_parameter = var.rds_password_parameter_name != null ? var.rds_password_parameter_name : ""
  db_host_parameter     = var.rds_host_parameter_name != null ? var.rds_host_parameter_name : ""
  db_name               = var.db_name != null ? var.db_name : ""
  db_username           = var.db_username != null ? var.db_username : ""
}

resource "aws_instance" "this" {
  ami           = data.aws_ssm_parameter.al2023_arm64.value
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # No `key_name` on purpose: there is no SSH port open and no key pair to
  # store, rotate or leak. Shell access is `aws ssm start-session`, which is
  # IAM-authenticated and logged.

  # IMDSv2 only. v1 answers a plain GET, so any SSRF bug in the app ("fetch this
  # URL for me") can read the instance credentials; v2 requires a PUT to get a
  # token first, which a naive proxy will not do.
  #
  # The hop limit is the TTL of the metadata response: containers on a bridge
  # network need 2 hops (host -> container), and the default of 1 makes every
  # boto3 call inside the container fail with NoCredentialsError.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region       = var.aws_region
    image_url    = var.image_url
    image_tag    = var.image_tag
    api_env      = var.api_env
    log_group    = var.log_group_name
    api_hostname = var.api_hostname
    domain_name  = var.domain_name

    rds_enabled = var.rds_enabled
    pw_param    = local.db_password_parameter
    host_param  = local.db_host_parameter
    db_name     = local.db_name
    db_user     = local.db_username
  })

  # user_data only ever runs on the first boot, so a changed script means a new
  # instance. Without this the file would drift silently and the box would keep
  # running the old configuration.
  user_data_replace_on_change = true

  lifecycle {
    # the SSM parameter tracks the latest AL2023 build; without this every AMI
    # release would replace the instance on an unrelated apply — refresh on
    # purpose with `terraform apply -replace`
    ignore_changes = [ami]
  }

  # Terraform only infers instance -> profile -> role, so nothing stops it
  # creating the box while the role is still an empty shell. The instance would
  # then boot, hit `aws ecr get-login-password` with no permissions and abort
  # user data on `set -e` — and Session Manager would not connect either,
  # because its managed policy is not attached yet. These two edges make the
  # permissions exist before anything can use them.
  depends_on = [
    aws_iam_role_policy.app,
    aws_iam_role_policy_attachment.ssm_session_manager,
  ]

  tags = {
    Name = "${var.name}-app"
  }
}

# A stopped or replaced instance gets a new public IP; the DNS record and the
# Let's Encrypt certificate both hang off a stable one. An EIP is free while
# attached to a running instance and ~3.6 USD/month otherwise — including while
# the instance is stopped, which is why "stop the instance" is not a free
# teardown.
resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-app"
  }
}

# Separate from the EIP so replacing the instance re-associates the same address
# instead of releasing and re-allocating it.
resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}

# The record lives in this module, not in `dns`, so its existence follows the
# module's own `count` (a known variable) instead of an IP address that is
# unknown at plan time — `count` on an unknown value is a plan-time error.
#
# TTL 60 because a replaced instance publishes a new address only when the EIP
# itself is recreated; a short TTL keeps that recovery to a minute.
resource "aws_route53_record" "api" {
  zone_id = var.zone_id
  name    = "${var.api_hostname}.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [aws_eip.this.public_ip]
}
