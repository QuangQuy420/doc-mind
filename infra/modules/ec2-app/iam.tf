# The instance's identity. Two policies with different jobs, which is the whole
# point of the IAM role model:
#
#   trust policy      — WHO may become this role (here: the EC2 service)
#   permission policy — WHAT the role may then do (below, scoped to ARNs)
#
# An *instance profile* is the container that hands a role to an EC2 instance;
# EC2 cannot be given a role directly. The credentials it produces are temporary
# and rotated by the metadata service, which is why there is no access key
# anywhere in this project.

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app"
  description        = "Instance role for the DocMind API host: ECR pull, documents table, its own log group, Session Manager."
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "app" {
  # `ecr:GetAuthorizationToken` returns the registry login token for the whole
  # account, so there is no resource to scope it to — AWS defines it as
  # resource-less and rejects any ARN here. This is the only `*` in the policy.
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # The actual pull, scoped to this one repository. Three actions because a pull
  # is three calls: read the manifest, check each layer, fetch the layer blob.
  statement {
    sid = "EcrPullApiImage"

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]

    resources = [var.ecr_repository_arn]
  }

  # Phase 1 only lists and writes documents, so no `Scan`, no `DeleteItem`, and
  # no `<table>/index/*` — the GSI is read by the Phase 2 worker, which will get
  # its own role.
  statement {
    sid = "DocumentsTable"

    actions = [
      "dynamodb:Query",
      "dynamodb:PutItem",
    ]

    resources = [var.dynamodb_table_arn]
  }

  # Only present while a database exists: with no RDS there is nothing to read,
  # and a statement with an empty resource list is invalid anyway. `dynamic`
  # rather than a `count` on a second policy keeps this one inline policy the
  # single place to read what the host may do.
  #
  # No `kms:Decrypt` is needed: the parameter is encrypted with the AWS-managed
  # `aws/ssm` key, whose key policy already allows SSM to decrypt on the
  # caller's behalf.
  dynamic "statement" {
    for_each = var.rds_enabled ? [1] : []

    content {
      sid       = "ReadDatabaseCredentials"
      actions   = ["ssm:GetParameter"]
      resources = compact([var.rds_password_parameter_arn, var.rds_host_parameter_arn])
    }
  }

  # The Docker `awslogs` driver uses these instance credentials. It only creates
  # streams and puts events — the group itself is created by Terraform, so
  # `CreateLogGroup` is deliberately absent. `:*` addresses the streams inside
  # the group, not other groups.
  statement {
    sid = "WriteApiLogs"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${var.log_group_arn}:*"]
  }
}

# Inline rather than a managed policy: it is meaningless without this role, and
# an inline policy is deleted together with it — a managed one would linger.
resource "aws_iam_role_policy" "app" {
  name   = "${var.name}-app"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

# AWS-managed, so its contents are not visible here: it grants the `ssmmessages`
# and `ec2messages` channels the Session Manager agent needs to open a session,
# plus a few `ssm:*` describe/update calls. Those are account-wide with no
# resource to scope them to, which is the second (and last) `*` in this module.
# Writing it by hand would mean tracking AWS's changes to it forever.
resource "aws_iam_role_policy_attachment" "ssm_session_manager" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app"
  role = aws_iam_role.app.name
}
