# The `documents` table: one item per uploaded document, holding its metadata and
# its processing status. The keys come from the access patterns, not the other
# way round — that is the whole DynamoDB design method:
#
#   "list my documents"            -> PK userId, SK documentId
#   "all PENDING documents by time"-> GSI on status / createdAt (P2)
#   "react to a status change"     -> Streams (P2 notify lambda)
#   "drop temporary items"         -> TTL on expiresAt
#
# The GSI, the stream and the TTL are created now even though nothing reads them
# until Phase 2: enabling a stream or a GSI later is an online change, but doing
# it here keeps the table shape in one place and costs nothing while unused.

resource "aws_dynamodb_table" "this" {
  name = var.name

  # On-demand: billed per request, nothing while idle. Provisioned capacity is
  # cheaper at steady high load but has to be sized (or auto-scaled) and bills
  # 24/7 — the wrong trade for a dev environment with spiky, unknown traffic.
  billing_mode = "PAY_PER_REQUEST"

  # The partition key decides how the data is spread over partitions, so it must
  # be high-cardinality: userId is. The sort key orders items *inside* one
  # partition, which is what makes "my documents" a single Query instead of a
  # Scan.
  hash_key  = "userId"
  range_key = "documentId"

  # Only attributes used in a key (table or index) are declared. DynamoDB is
  # schemaless for everything else — title, size, error_message and the rest are
  # written by the API without ever appearing here.
  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "documentId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # A GSI is a separate copy of the table with its own keys and its own
  # capacity, kept in sync asynchronously — so reads from it are eventually
  # consistent. (An LSI shares the table's partition key, is strongly
  # consistent, and can only be created together with the table.) This one
  # answers the cross-user "which documents are still PENDING, oldest first"
  # question the Phase 2 worker asks.
  #
  # projection_type = "ALL" copies every attribute into the index, so a query
  # never has to fetch the base item afterwards. It costs storage (a second full
  # copy); the table is tiny, and KEYS_ONLY / INCLUDE would trade that for an
  # extra read per item.
  global_secondary_index {
    name            = "status-createdAt-index"
    hash_key        = "status"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # The stream is an ordered change log per partition, kept for 24 hours, that a
  # Lambda can be triggered from — the "database event -> notification" story of
  # Phase 2. NEW_AND_OLD_IMAGES gives both the before and after item, which is
  # what lets a handler see *that the status changed* rather than only its new
  # value.
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  # TTL deletes expired items for free (no write capacity charged), within about
  # 48 hours of the timestamp — it is a cleanup mechanism, not a deadline. The
  # attribute holds a Unix epoch in seconds; items without it are never expired.
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # PITR is continuous backup with restore to any second in the last 35 days,
  # billed per GB of table size. Off in dev: the data is reproducible by
  # re-uploading, and this is the kind of always-on cost the project avoids.
  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name = var.name
  }
}
