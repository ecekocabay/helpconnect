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
            # ✅ important for Cognito Authorizer + browser/Flutter web
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        "body": body,
    }


def _convert_decimals(obj):
    """Recursively convert DynamoDB Decimals into int/float so json.dumps works."""
    if isinstance(obj, list):
        return [_convert_decimals(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        return float(obj)
    return obj


def lambda_handler(event, context):
    """
    GET /offers?requestId=<id>

    Returns:
      { "items": [...], "count": N }
    """
    try:
        # ✅ safer debug print (event is always JSON-like)
        print("Incoming event:", json.dumps(event))

        # REST API usually has queryStringParameters
        qs = event.get("queryStringParameters") or {}

        # Sometimes frameworks might pass different casing/keys
        request_id = (
            qs.get("requestId")
            or qs.get("request_id")
            or qs.get("requestID")
        )

        if not request_id:
            return _build_response(400, {"message": "Missing required query parameter: requestId"})

        try:
            response = table.query(
                KeyConditionExpression=Key("request_id").eq(request_id),
                Limit=100,
            )
            items = response.get("Items", [])
        except ClientError as e:
            print("DynamoDB query error:", str(e))
            return _build_response(
                500,
                {"message": "Failed to query offers from DynamoDB", "error": str(e)},
            )

        cleaned_items = _convert_decimals(items)

        return _build_response(200, {"items": cleaned_items, "count": len(cleaned_items)})

    except Exception as e:
        print("Unhandled exception in ListOffers:", str(e))
        return _build_response(
            500,
            {"message": "Internal server error while listing offers", "error": str(e)},
        )