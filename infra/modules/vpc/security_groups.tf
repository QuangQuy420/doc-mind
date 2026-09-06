# Security groups are STATEFUL: the reply to an allowed inbound packet is always
# allowed back out, so there is never a "response" rule to write. Their
# stateless, subnet-level counterpart is the NACL — the default one allows
# everything and is deliberately left alone; SGs are the instance-level control
# that is actually worth managing.
#
# Rules live in standalone `aws_vpc_security_group_ingress_rule` /
# `..._egress_rule` resources, never in inline `ingress`/`egress` blocks. Two
# reasons: the inline form makes the group resource authoritative over every
# rule, so the two styles overwrite each other on every apply; and only the
# standalone form gives each rule its own AWS rule id, which means a rule can be
# changed without churning the whole group.

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Inbound HTTP/HTTPS from the internet for the API host"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP from anywhere"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS from anywhere"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# There is no port 22 rule anywhere in this project, on purpose: shell access to
# the app host goes through SSM Session Manager (P8), which needs no inbound
# rule and leaves an audit trail.

# Terraform removes the allow-all egress rule AWS adds to a new security group
# as soon as it manages that group, so outbound has to be written out. It stays
# wide open because the API calls Bedrock, S3, DynamoDB and ECR — public AWS
# endpoints whose IP ranges change; narrowing this would mean tracking AWS
# managed prefix lists per service for no real gain on an egress path.
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound"

  cidr_ipv4 = "0.0.0.0/0"

  # "-1" means every protocol; from_port/to_port must then be omitted.
  ip_protocol = "-1"
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "PostgreSQL access for the app security group only"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-rds"
  }
}

# Referencing the app security group instead of a CIDR is the point of SGs: the
# rule keeps working whatever private IP the app host gets, it cannot
# accidentally match another instance in the same subnet, and no IP address ever
# appears in the config.
resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL from the app security group"

  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# No egress rule for the RDS group, on purpose. RDS only ever answers
# connections it did not start, and stateful rules already let those replies
# out. With Terraform managing the group and no egress rule declared, the
# database can open no outbound connection at all.
