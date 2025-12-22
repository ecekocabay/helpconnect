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


def _extract_request_id(event) -> str | None:
    """
    Supports:
      - REST API:  /help-requests/{id}  -> pathParameters.id
      - REST API:  /help-requests/{requestId} -> pathParameters.requestId
      - HTTP API proxy: /help-requests/{proxy+} -> pathParameters.proxy (last segment)
    """
    path_params = event.get("pathParameters") or {}

    # common names
    rid = path_params.get("id") or path_params.get("requestId") or path_params.get("request_id")
    if rid:
        return rid

    # proxy style: "help-requests/abc-123" or "abc-123"
    proxy = path_params.get("proxy")
    if proxy:
        # take last segment after slash
        parts = [p for p in str(proxy).split("/") if p]
        if parts:
            return parts[-1]

    return None


def lambda_handler(event, context):
    """
    GET /help-requests/{id}
    """
    try:
        print("Incoming event:", json.dumps(event))

        # CORS preflight (REST API v1 or HTTP API v2)
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        request_id = _extract_request_id(event)
        if not request_id:
            return _build_response(400, {"message": "Missing path parameter: id"})

        try:
            resp = table.get_item(Key={"request_id": request_id})
            item = resp.get("Item")
        except ClientError as e:
            return _build_response(
                500,
                {"message": "Failed to get item from DynamoDB", "error": str(e)},
            )

        if not item:
            return _build_response(404, {"message": f"Help request {request_id} not found"})

        item = _convert_decimals(item)
        return _build_response(200, item)

    except Exception as e:
        print("Unhandled exception:", str(e))
        return _build_response(500, {"message": "Internal server error", "error": str(e)})