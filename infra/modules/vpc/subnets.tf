# One public and one private subnet per AZ. `for_each` rather than `count` so a
# third AZ later adds a new key instead of renumbering — and therefore
# destroying and recreating — the existing subnets. `for_each` map keys must be
# strings, so the AZ index is kept as "0" / "1" and converted back with
# `tonumber` where the CIDR maths needs it.
locals {
  subnet_azs = { for i in range(var.az_count) : tostring(i) => local.azs[i] }
}

# 10.0.0.0/24 and 10.0.1.0/24. Nothing on the subnet itself makes it public —
# only the route table in routing.tf does. `map_public_ip_on_launch` just saves
# attaching an EIP to everything that needs to be reachable.
resource "aws_subnet" "public" {
  for_each = local.subnet_azs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(var.cidr, 8, tonumber(each.key))
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  }
}

# 10.0.10.0/24 and 10.0.11.0/24. The +10 offset deliberately leaves
# 10.0.2.0/24 … 10.0.9.0/24 unused so more public subnets (ECS in Phase 4) can
# be added later without moving the private ones.
resource "aws_subnet" "private" {
  for_each = local.subnet_azs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(var.cidr, 8, tonumber(each.key) + 10)

  tags = {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  }
}
