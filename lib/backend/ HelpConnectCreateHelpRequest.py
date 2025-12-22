import json
import os
import uuid
from datetime import datetime
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

# -------------------------------
# AWS region + clients
# -------------------------------
AWS_REGION = (
    os.environ.get("AWS_REGION")
    or os.environ.get("AWS_DEFAULT_REGION")
    or "eu-central-1"
)

dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
sns = boto3.client("sns", region_name=AWS_REGION)

TABLE_NAME = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
table = dynamodb.Table(TABLE_NAME)

SNS_NEW_REQUESTS_TOPIC_ARN = os.environ.get("SNS_NEW_REQUESTS_TOPIC_ARN", "").strip()

# -------------------------------
# Helpers
# -------------------------------
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

    # HTTP API v2 JWT authorizer
    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        claims = jwt.get("claims") or {}
        sub = claims.get("sub")
        if sub:
            return sub

    # REST API v1 authorizer
    claims = auth.get("claims") or {}
    return claims.get("sub")


def _to_decimal(x):
    if x is None:
        return None
    try:
        return Decimal(str(x))
    except Exception:
        return None


def _geo_prefix_5(lat_dec: Decimal, lng_dec: Decimal) -> str:
    lat_r = lat_dec.quantize(Decimal("0.01"))
    lng_r = lng_dec.quantize(Decimal("0.01"))
    return f"lat:{lat_r}|lng:{lng_r}"


def _notify_all_subscribers(*, title: str, urgency: str, location: str, request_id: str) -> None:
    """
    Broadcast a notification to everyone subscribed to SNS_NEW_REQUESTS_TOPIC_ARN.
    Best-effort: never raise (so request creation won't fail).
    """
    print("SNS region:", sns.meta.region_name)
    print("SNS_NEW_REQUESTS_TOPIC_ARN:", repr(SNS_NEW_REQUESTS_TOPIC_ARN))

    if not SNS_NEW_REQUESTS_TOPIC_ARN:
        print("SNS_NEW_REQUESTS_TOPIC_ARN not set; skipping notification")
        return

    message_text = (
        "New HelpConnect request posted!\n\n"
        f"Title: {title}\n"
        f"Urgency: {urgency}\n"
        f"Location: {location}\n"
        f"Request ID: {request_id}\n"
    )

    try:
        resp = sns.publish(
            TopicArn=SNS_NEW_REQUESTS_TOPIC_ARN,
            Subject="HelpConnect: New Help Request",
            Message=message_text,
        )
        print("SNS publish OK. MessageId:", resp.get("MessageId"))
    except ClientError as e:
        # This will catch AccessDenied, invalid topic ARN, etc.
        print("SNS publish FAILED (ClientError):", str(e))
    except Exception as e:
        print("SNS publish FAILED (Unknown):", str(e))


# -------------------------------
# Lambda handler
# -------------------------------
def lambda_handler(event, context):
    try:
        print("Incoming event:", json.dumps(event))

        # CORS preflight
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        help_seeker_id = _get_cognito_sub(event)
        if not help_seeker_id:
            return _build_response(401, {"message": "Unauthorized"})

        # Parse body
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

        # Validate required fields
        required = ["title", "description", "category", "urgency", "location"]
        missing = [f for f in required if not body.get(f)]
        if missing:
            return _build_response(400, {"message": f"Missing fields: {', '.join(missing)}"})

        title = str(body["title"]).strip()
        description = str(body["description"]).strip()
        category = str(body["category"]).strip()
        urgency = str(body["urgency"]).strip()
        location = str(body["location"]).strip()
        image_key = body.get("imageKey")

        lat_dec = _to_decimal(body.get("latitude"))
        lng_dec = _to_decimal(body.get("longitude"))

        now = datetime.utcnow().isoformat() + "Z"
        request_id = str(uuid.uuid4())

        item = {
            "request_id": request_id,
            "help_seeker_id": help_seeker_id,
            "title": title,
            "description": description,
            "category": category,
            "urgency": urgency,
            "location": location,
            "image_key": image_key,
            "status": "OPEN",
            "created_at": now,
            "offers": [],
        }

        if lat_dec is not None and lng_dec is not None:
            item["latitude"] = lat_dec
            item["longitude"] = lng_dec
            item["geo_prefix_5"] = _geo_prefix_5(lat_dec, lng_dec)

        # 1) Save request (source of truth)
        try:
            table.put_item(Item=item)
        except ClientError as e:
            return _build_response(
                500,
                {"message": "Failed to save help request", "error": str(e)},
            )

        # 2) Notify (best-effort; never fail creation)
        _notify_all_subscribers(
            title=title,
            urgency=urgency,
            location=location,
            request_id=request_id,
        )

        return _build_response(
            201,
            {"message": "Help request created successfully", "requestId": request_id},
        )

    except Exception as e:
        print("Unhandled exception:", str(e))
        return _build_response(
            500,
            {"message": "Internal server error", "error": str(e)},
        )