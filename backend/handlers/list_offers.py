import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("OFFERS_TABLE_NAME", "HelpOffers")
table = dynamodb.Table(TABLE_NAME)


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


def _convert_decimals(obj):
    """
    Recursively convert DynamoDB Decimals into int/float so json.dumps works.
    """
    if isinstance(obj, list):
        return [_convert_decimals(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        # If it's an integer like 15, return int; otherwise float
        if obj % 1 == 0:
            return int(obj)
        return float(obj)
    return obj


def lambda_handler(event, context):
    """
    GET /offers?requestId=<id>

    Returns:
      {
        "items": [...],
        "count": N
      }
    """
    try:
        print("Incoming event:", json.dumps(event))

        qs = event.get("queryStringParameters") or {}
        request_id = qs.get("requestId") or qs.get("request_id")

        if not request_id:
            return _build_response(
                400,
                {"message": "Missing required query parameter: requestId"},
            )

        try:
            response = table.query(
                KeyConditionExpression=Key("request_id").eq(request_id),
                Limit=100,
            )
            items = response.get("Items", [])
        except ClientError as e:
            print("DynamoDB query error:", e)
            return _build_response(
                500,
                {
                    "message": "Failed to query offers from DynamoDB",
                    "error": str(e),
                },
            )

        # ✅ Convert Decimal -> int/float before returning
        cleaned_items = _convert_decimals(items)

        return _build_response(
            200,
            {
                "items": cleaned_items,
                "count": len(cleaned_items),
            },
        )

    except Exception as e:
        print("Unhandled exception in ListOffers:", e)
        return _build_response(
            500,
            {"message": "Internal server error while listing offers", "error": str(e)},
        )