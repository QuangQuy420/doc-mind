# Gateway endpoints keep S3 and DynamoDB traffic inside the AWS network instead
# of sending it out through the IGW — or, from a private subnet, through the NAT
# at ~0.045 USD per GB. They cost nothing: AWS implements them as a prefix-list
# route added to every route table you attach them to, not as an ENI.
#
# Only S3 and DynamoDB offer this flavour. Every other service (Bedrock, SSM,
# ECR, Secrets Manager) needs an *interface* endpoint, which is an ENI billed
# per hour per AZ plus per GB — deliberately not used here.

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.this.id

  # `.region` is the attribute in AWS provider v6; `.name` is deprecated.
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attached to both tables so the route exists whether the caller sits in a
  # public or a private subnet.
  route_table_ids = [aws_route_table.public.id, aws_route_table.private.id]

  # No `policy` argument, so AWS attaches the default full-access endpoint
  # policy. It is not the access control here — the caller's IAM role and the
  # bucket policy still decide what may be read or written; the endpoint policy
  # is a second, optional filter to be tightened once real buckets exist (P4).

  tags = {
    Name = "${var.name}-s3"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id = aws_vpc.this.id

  service_name      = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = {
    Name = "${var.name}-dynamodb"
  }
}
