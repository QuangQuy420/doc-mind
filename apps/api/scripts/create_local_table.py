"""Create the documents table in DynamoDB Local.

Mirrors infra/modules/dynamodb (keys, GSI, TTL) so local behaviour matches AWS.
Idempotent: running it twice is a no-op. It never touches real AWS — it refuses
to run unless DYNAMODB_ENDPOINT_URL points at a local endpoint.
"""

import sys

import boto3
from app.core.config import get_settings
from botocore.exceptions import ClientError


def main() -> int:
    settings = get_settings()
    endpoint = settings.dynamodb_endpoint_url
    if not endpoint:
        print("DYNAMODB_ENDPOINT_URL is not set - refusing to create a table in real AWS.")
        return 1

    dynamodb = boto3.client(
        "dynamodb",
        region_name=settings.aws_region,
        endpoint_url=endpoint,
        # DynamoDB Local ignores credentials but botocore still requires some.
        aws_access_key_id="local",
        aws_secret_access_key="local",
    )
    name = settings.dynamodb_table_name

    try:
        dynamodb.create_table(
            TableName=name,
            BillingMode="PAY_PER_REQUEST",
            KeySchema=[
                {"AttributeName": "userId", "KeyType": "HASH"},
                {"AttributeName": "documentId", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "userId", "AttributeType": "S"},
                {"AttributeName": "documentId", "AttributeType": "S"},
                {"AttributeName": "status", "AttributeType": "S"},
                {"AttributeName": "createdAt", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "status-createdAt-index",
                    "KeySchema": [
                        {"AttributeName": "status", "KeyType": "HASH"},
                        {"AttributeName": "createdAt", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                }
            ],
            StreamSpecification={"StreamEnabled": True, "StreamViewType": "NEW_AND_OLD_IMAGES"},
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "ResourceInUseException":
            raise
        print(f"Table {name} already exists at {endpoint}.")
        return 0

    dynamodb.get_waiter("table_exists").wait(TableName=name)
    # TTL cannot be part of CreateTable; it is a separate call in AWS too.
    dynamodb.update_time_to_live(
        TableName=name,
        TimeToLiveSpecification={"Enabled": True, "AttributeName": "expiresAt"},
    )
    print(f"Created table {name} at {endpoint}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
