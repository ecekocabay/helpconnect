import json
import os
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError


dynamodb = boto3.resource("dynamodb")
OFFERS_TABLE_NAME = os.environ.get("OFFERS_TABLE_NAME", "HelpOffers")
VOLUNTEER_GSI = os.environ.get("VOLUNTEER_GSI", "volunteer_id-index")
table = dynamodb.Table(OFFERS_TABLE_NAME)


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


def _get_user_sub(event) -> str:
    """
    Support multiple API Gateway authorizer shapes to extract Cognito 'sub'.
    - HTTP API with JWT authorizer: event['requestContext']['authorizer']['jwt']['claims']['sub']
    - REST API Lambda authorizer: event['requestContext']['authorizer']['claims']['sub']
    """
    try:
        rc = event.get("requestContext", {})
        # HTTP API v2 JWT authorizer
        authorizer = rc.get("authorizer") or {}
        jwt = authorizer.get("jwt") or {}
        claims = jwt.get("claims") or authorizer.get("claims") or {}
        sub = claims.get("sub")
        if sub:
            return sub
    except Exception:
        pass

    return ""


def lambda_handler(event, context):
    """
    GET /my-offers

    Return all offers made by the authenticated volunteer (volunteer_id == sub)
    """
    try:
        print("Incoming event:", json.dumps(event))

        if not OFFERS_TABLE_NAME:
            return _build_response(500, {"message": "Missing env var", "error": "OFFERS_TABLE_NAME"})

        user_sub = _get_user_sub(event)
        if not user_sub:
            return _build_response(401, {"message": "Unauthorized: missing user sub"})

        try:
            response = table.query(
                IndexName=VOLUNTEER_GSI,
                KeyConditionExpression=Key("volunteer_id").eq(user_sub),
                Limit=200,
            )
            items = response.get("Items", [])
        except ClientError as e:
            print("DynamoDB query error:", e)
            return _build_response(500, {"message": "Failed to query offers from DynamoDB", "error": str(e)})

        # Convert Decimal -> int/float before returning
        cleaned_items = _convert_decimals(items)

        # Optionally sort by created_at if present (newest first)
        try:
            cleaned_items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        except Exception:
            pass

        return _build_response(200, {"items": cleaned_items, "count": len(cleaned_items)})

    except Exception as e:
        print("Unhandled exception in ListMyOffers:", e)
        return _build_response(500, {"message": "Internal server error while listing my offers", "error": str(e)})
