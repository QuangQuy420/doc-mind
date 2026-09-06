output "vpc_id" {
  description = "Id of the VPC every other module attaches to."
  value       = aws_vpc.this.id
}

# The subnets are a `for_each` map, so ordering is not guaranteed by the map
# itself. Building the list by index over `range(var.az_count)` makes element 0
# always the subnet in AZ 0 — P8 puts the EC2 host in `public_subnet_ids[0]` and
# must get the same AZ on every run.
output "public_subnet_ids" {
  description = "Public subnet ids, ordered by AZ index (element 0 is AZ 0)."
  value       = [for i in range(var.az_count) : aws_subnet.public[tostring(i)].id]
}

output "private_subnet_ids" {
  description = "Private subnet ids, ordered by AZ index. P5 uses them for the RDS subnet group."
  value       = [for i in range(var.az_count) : aws_subnet.private[tostring(i)].id]
}

output "app_sg_id" {
  description = "Security group for the API host: inbound 80/443, all outbound."
  value       = aws_security_group.app.id
}

output "rds_sg_id" {
  description = "Security group for the database: inbound 5432 from the app security group only."
  value       = aws_security_group.rds.id
}

output "private_route_table_id" {
  description = "Private route table id, so a later module can add its own routes (e.g. a VPC peering or an extra endpoint)."
  value       = aws_route_table.private.id
}
