import json
import os
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)

HELP_REQUESTS_TABLE = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
table = dynamodb.Table(HELP_REQUESTS_TABLE)

def _build_response(code, body):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "PATCH,OPTIONS",
        },
        "body": json.dumps(body),
    }

def _get_method(event):
    # REST v1: event["httpMethod"], HTTP API v2: requestContext.http.method
    return (event.get("httpMethod")
            or (event.get("requestContext") or {}).get("http", {}).get("method")
            or "").upper()

def _get_sub(event):
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}
    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        return (jwt.get("claims") or {}).get("sub")
    return (auth.get("claims") or {}).get("sub")

def _get_request_id(event):
    pp = event.get("pathParameters") or {}

    # ✅ accept all common names
    rid = pp.get("request_id") or pp.get("requestId") or pp.get("id")
    if rid:
        return rid

    # fallback: try rawPath parsing (HTTP API)
    raw = event.get("rawPath") or ""
    # expected: /prod/help-requests/<id>/close OR /help-requests/<id>/close
    parts = [p for p in raw.split("/") if p]
    # find "... help-requests <id> close"
    for i in range(len(parts) - 2):
        if parts[i] == "help-requests" and parts[i + 2] == "close":
            return parts[i + 1]
    return None

def lambda_handler(event, context):
    method = _get_method(event)

    if method == "OPTIONS":
        return _build_response(200, {"message": "OK"})

    if method != "PATCH":
        return _build_response(405, {"message": f"Method {method} not allowed"})

    user_sub = _get_sub(event)
    if not user_sub:
        return _build_response(401, {"message": "Unauthorized"})

    request_id = _get_request_id(event)
    if not request_id:
        # ✅ this is the exact bug that often causes “Not Found”
        return _build_response(400, {
            "message": "Missing request_id in pathParameters",
            "pathParameters": event.get("pathParameters"),
            "rawPath": event.get("rawPath"),
        })

    # ✅ close only if owner + status IN_PROGRESS
    try:
        # read request
        resp = table.get_item(Key={"request_id": request_id})
        item = resp.get("Item")
        if not item:
            return _build_response(404, {"message": "Request not found"})

        if item.get("help_seeker_id") != user_sub:
            return _build_response(403, {"message": "Forbidden: not your request"})

        status = (item.get("status") or "").upper()
        if status != "IN_PROGRESS":
            return _build_response(409, {"message": "Can close only when IN_PROGRESS", "status": status})

        now = datetime.utcnow().isoformat() + "Z"

        table.update_item(
            Key={"request_id": request_id},
            UpdateExpression="SET #s = :closed, closed_at = :now",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":closed": "CLOSED", ":now": now},
        )

        return _build_response(200, {"message": "Request closed", "requestId": request_id})

    except ClientError as e:
        return _build_response(500, {"message": "DynamoDB error", "error": str(e)})
    except Exception as e:
        return _build_response(500, {"message": "Internal server error", "error": str(e)})