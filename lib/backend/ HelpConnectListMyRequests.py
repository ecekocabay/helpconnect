import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
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


def _get_cognito_sub(event):
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}

    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        claims = jwt.get("claims") or {}
        sub = claims.get("sub")
        if sub:
            return sub

    claims = auth.get("claims") or {}
    sub = claims.get("sub")
    if sub:
        return sub

    return None


def lambda_handler(event, context):
    """
    GET /my-requests

    ✅ help_seeker_id is inferred from Cognito token (sub)
    Uses GSI: help_seeker_id-index
    """
    try:
        print("Incoming event:", json.dumps(event))

        # CORS preflight (REST API v1 or HTTP API v2)
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        help_seeker_id = _get_cognito_sub(event)
        if not help_seeker_id:
            return _build_response(401, {"message": "Unauthorized: missing Cognito user identity (sub)."})

        # Query DynamoDB using GSI + pagination
        items = []
        last_key = None

        try:
            while True:
                kwargs = {
                    "IndexName": "help_seeker_id-index",
                    "KeyConditionExpression": Key("help_seeker_id").eq(help_seeker_id),
                    "Limit": 100,
                }
                if last_key:
                    kwargs["ExclusiveStartKey"] = last_key

                resp = table.query(**kwargs)
                items.extend(resp.get("Items", []))

                last_key = resp.get("LastEvaluatedKey")
                if not last_key:
                    break

        except ClientError as e:
            return _build_response(
                500,
                {"message": "Failed to query DynamoDB for this user", "error": str(e)},
            )

        # Convert Decimal → int/float (this is what makes latitude/longitude safe)
        items = _convert_decimals(items)

        # Sort newest first
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        return _build_response(200, {"items": items, "count": len(items)})

    except Exception as e:
        print("Unhandled exception:", str(e))
        return _build_response(500, {"message": "Internal server error", "error": str(e)})