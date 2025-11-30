import json
import os
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")

# Use same env var/table name convention as other lambdas
TABLE_NAME = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
table = dynamodb.Table(TABLE_NAME)


# -------------------------------
# Convert DynamoDB Decimal → int/float
# -------------------------------
def _convert_decimals(obj):
    """
    Recursively convert DynamoDB Decimal values into Python int/float
    so json.dumps can serialize them.
    """
    if isinstance(obj, list):
        return [_convert_decimals(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj


# -------------------------------
# Standard API Gateway response builder
# -------------------------------
def _build_response(status_code: int, body):
    if not isinstance(body, str):
        body = json.dumps(body)

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": body,
    }


# -------------------------------
# Lambda handler
# -------------------------------
def lambda_handler(event, context):
    """
    List all emergencies for volunteers.

    GET /emergencies
    """
    try:
        try:
            # Basic scan – Stage 2 is fine with this
            response = table.scan(Limit=200)
            items = response.get("Items", [])
        except ClientError as e:
            return _build_response(
                500,
                {
                    "message": "Failed to read from DynamoDB",
                    "error": str(e),
                },
            )

        # Convert Decimal → int/float for JSON
        items = _convert_decimals(items)

        # Optional: sort newest first if created_at exists
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        return _build_response(
            200,
            {
                "items": items,
                "count": len(items),
            },
        )

    except Exception as e:
        # Catch-all just in case
        return _build_response(
            500,
            {
                "message": "Internal server error",
                "error": str(e),
            },
        )