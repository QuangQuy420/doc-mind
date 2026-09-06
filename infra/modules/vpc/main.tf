# The network layer for one environment: the VPC itself, its subnets, routing,
# the free S3/DynamoDB gateway endpoints and the two security groups later
# phases attach to. RDS (P5), EC2 (P8) and ECS (Phase 4) all take subnet and
# security group ids from this module's outputs instead of creating their own.
#
# One concern per file: main.tf (VPC, IGW, AZ lookup) · subnets.tf · routing.tf
# · endpoints.tf · security_groups.tf.

# Which AZs an account can use differs per account and per region, so they are
# read at plan time rather than hard-coded. The `opt-in-status` filter drops
# Local Zones and Wavelength Zones, which most resource types cannot launch in.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # The API returns the names sorted, so index 0 stays the same AZ across runs.
  # Slicing to az_count keeps the subnet-to-AZ mapping fixed if the region later
  # gains an AZ.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr

  # DNS support switches on the VPC resolver (.2 address), which is what makes
  # the S3/DynamoDB endpoint and, later, the RDS endpoint name resolvable from
  # inside the VPC. DNS hostnames gives instances a resolvable name; RDS and
  # interface endpoints both refuse to work without it.
  enable_dns_support   = true
  enable_dns_hostnames = true

  # Only `Name` and `Tier` are set per resource — Project/Env/ManagedBy come
  # from the provider's `default_tags`.
  tags = {
    Name = var.name
  }
}

# The Internet Gateway is free, horizontally scaled and stateless. On its own it
# does nothing: a subnet only becomes "public" once a route table sends
# 0.0.0.0/0 at this gateway (routing.tf).
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}
