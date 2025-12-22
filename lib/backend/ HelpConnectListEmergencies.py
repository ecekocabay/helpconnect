import json
import os
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")

TABLE_NAME = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
table = dynamodb.Table(TABLE_NAME)


def _convert_decimals(obj):
    if isinstance(obj, list):
        return [_convert_decimals(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj


def _build_response(status_code: int, body):
    if not isinstance(body, str):
        body = json.dumps(body)

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        "body": body,
    }


def _has_location(item: dict) -> bool:
    lat = item.get("latitude")
    lng = item.get("longitude")
    return lat is not None and lng is not None


def lambda_handler(event, context):
    """
    GET /emergencies

    Optional query params:
      - status=OPEN
      - onlyWithLocation=true
    """
    try:
        print("Incoming event:", json.dumps(event))

        # CORS preflight (REST v1 or HTTP v2)
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        qs = event.get("queryStringParameters") or {}
        status_filter = (qs.get("status") or "").strip()
        only_with_location = (qs.get("onlyWithLocation") or "").strip().lower() in (
            "1",
            "true",
            "yes",
        )

        try:
            # NOTE: scan is OK for MVP; later replace with index-based queries.
            response = table.scan(Limit=200)
            items = response.get("Items", [])
        except ClientError as e:
            return _build_response(
                500,
                {"message": "Failed to read from DynamoDB", "error": str(e)},
            )

        # Convert Decimal -> int/float
        items = _convert_decimals(items)

        # Optional filters
        if status_filter:
            items = [
                it for it in items
                if str(it.get("status", "")).strip().upper() == status_filter.upper()
            ]

        if only_with_location:
            items = [it for it in items if _has_location(it)]

        # Sort newest first
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        return _build_response(200, {"items": items, "count": len(items)})

    except Exception as e:
        print("Unhandled exception:", str(e))
        return _build_response(500, {"message": "Internal server error", "error": str(e)})