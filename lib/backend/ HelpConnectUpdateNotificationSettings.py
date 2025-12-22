import json
import os
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("NOTIF_TABLE_NAME", "NotificationSettings")
table = dynamodb.Table(TABLE_NAME)


def _build_response(status_code: int, body):
    if not isinstance(body, str):
        body = json.dumps(body)
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        "body": body,
    }


def _get_cognito_sub(event):
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}

    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        claims = jwt.get("claims") or {}
        if claims.get("sub"):
            return claims["sub"]

    claims = auth.get("claims") or {}
    return claims.get("sub")


def lambda_handler(event, context):
    try:
        # CORS preflight
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        user_id = _get_cognito_sub(event)
        if not user_id:
            return _build_response(401, {"message": "Unauthorized: missing user sub"})

        body_raw = event.get("body") or "{}"
        if isinstance(body_raw, str):
            try:
                body = json.loads(body_raw)
            except json.JSONDecodeError:
                return _build_response(400, {"message": "Invalid JSON body"})
        elif isinstance(body_raw, dict):
            body = body_raw
        else:
            return _build_response(400, {"message": "Unsupported body format"})

        # Expect: { "notify_enabled": true/false }
        if "notify_enabled" not in body:
            return _build_response(400, {"message": "Missing field: notify_enabled"})

        notify_enabled = bool(body["notify_enabled"])
        now = datetime.utcnow().isoformat() + "Z"

        try:
            table.put_item(
                Item={
                    "user_id": user_id,
                    "notify_enabled": notify_enabled,
                    "updated_at": now,
                }
            )
        except ClientError as e:
            return _build_response(500, {"message": "Failed to save settings", "error": str(e)})

        return _build_response(
            200,
            {
                "message": "Notification setting updated",
                "user_id": user_id,
                "notify_enabled": notify_enabled,
                "updated_at": now,
            },
        )

    except Exception as e:
        return _build_response(500, {"message": "Internal server error", "error": str(e)})