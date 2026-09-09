# Application logs. The API prints one JSON line per request to stdout and the
# Docker `awslogs` driver on the EC2 host ships it here — no log agent, no files
# on the box. Created unconditionally (not behind `enable_ec2`): an empty log
# group is free, and it must exist before the driver writes to it, otherwise the
# container fails to start.
resource "aws_cloudwatch_log_group" "api" {
  name = "/docmind/api"

  # CloudWatch bills ~0.03 USD/GB/month for storage and never expires data by
  # itself — the default is "keep forever", which is how log bills grow without
  # anyone noticing. Seven days is longer than any debugging session here.
  retention_in_days = 7

  tags = {
    Name = "/docmind/api"
  }
}

# A saved Logs Insights query. It is only a stored string — it costs nothing and
# runs nothing until it is opened in the console — but it turns "what is slow?"
# into one click instead of a remembered query language.
#
# `path` and `latency_ms` are fields the API's structlog middleware puts on the
# `request.completed` line (apps/api/app/core/middleware.py); Insights discovers
# them automatically because the line is JSON. `ispresent` filters out the
# container's other lines (startup, uvicorn, tracebacks), which have no latency.
resource "aws_cloudwatch_query_definition" "api_p95_per_route" {
  name            = "docmind-dev-api-p95-per-route"
  log_group_names = [aws_cloudwatch_log_group.api.name]

  query_string = <<-QUERY
    fields path, latency_ms
    | filter ispresent(latency_ms)
    | stats pct(latency_ms, 95) as p95_ms, count() as requests by path
    | sort p95_ms desc
  QUERY
}
