# A route table is the entire difference between a public and a private subnet.
# Both public subnets share one table (their routes are identical); both private
# subnets share one too.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

# This single route is what "public subnet" means.
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# A subnet not associated with any table falls back to the VPC's main route
# table, which has only the local route — so the associations are what actually
# apply the routes above.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One private table shared by both AZs. The high-availability pattern is one
# table and one NAT Gateway per AZ, so an AZ outage cannot take the other AZ's
# egress down with it; that doubles the NAT bill, which is not worth it in a dev
# environment where the NAT is normally off anyway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# --- NAT Gateway: the only billable resource in this module -------------------
# Roughly 32 USD/month plus ~0.045 USD per GB processed, so it sits behind a
# toggle that defaults to false. With it off the private subnets simply have no
# default route: they can still reach S3 and DynamoDB through the gateway
# endpoints, and nothing else off-VPC.
# `count` (not `for_each`) because this is an on/off switch, not a named set.

resource "aws_eip" "nat" {
  count = var.enable_nat ? 1 : 0

  # `domain = "vpc"` replaced the removed boolean `vpc = true` argument.
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat ? 1 : 0

  allocation_id = aws_eip.nat[0].id

  # A NAT Gateway lives in a PUBLIC subnet: it reaches the internet through the
  # IGW on behalf of the private subnets. Putting it in a private subnet is the
  # classic mistake — it would have no way out itself.
  subnet_id = aws_subnet.public["0"].id

  # AWS documents this dependency explicitly. Terraform cannot infer it because
  # no attribute of the IGW is referenced here, and a NAT created before the IGW
  # is attached comes up but cannot route.
  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${var.name}-nat"
  }
}

# Outbound only: the NAT translates connections the private subnets start.
# Nothing on the internet can open a connection back through it.
resource "aws_route" "private_default" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}
