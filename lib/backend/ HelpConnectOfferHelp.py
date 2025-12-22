import json
import os
import uuid
from datetime import datetime
from typing import Optional

import boto3
from botocore.exceptions import ClientError

# DynamoDB
dynamodb = boto3.resource("dynamodb")

AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
sns = boto3.client("sns", region_name=AWS_REGION)
cognito = boto3.client("cognito-idp", region_name=AWS_REGION)

OFFERS_TABLE_NAME = os.environ.get("OFFERS_TABLE_NAME", "HelpOffers")
HELP_REQUESTS_TABLE_NAME = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
NOTIF_TABLE_NAME = os.environ.get("NOTIF_TABLE_NAME", "NotificationSettings")
USER_POOL_ID = os.environ.get("USER_POOL_ID", "")  # ✅ Add your Cognito User Pool ID

offers_table = dynamodb.Table(OFFERS_TABLE_NAME)
requests_table = dynamodb.Table(HELP_REQUESTS_TABLE_NAME)
notif_table = dynamodb.Table(NOTIF_TABLE_NAME)

SNS_NEW_OFFERS_TOPIC_ARN = os.environ.get("SNS_NEW_OFFERS_TOPIC_ARN", "")


def _build_response(status_code: int, body):
    if not isinstance(body, str):
        body = json.dumps(body, default=str)
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


def _get_cognito_claims(event) -> dict:
    """
    Supports BOTH:
      - HTTP API JWT authorizer: requestContext.authorizer.jwt.claims
      - REST API / older:       requestContext.authorizer.claims
    """
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}

    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        claims = jwt.get("claims")
        if isinstance(claims, dict):
            return claims

    claims = auth.get("claims")
    if isinstance(claims, dict):
        return claims

    return {}


def _get_cognito_sub(event) -> Optional[str]:
    claims = _get_cognito_claims(event)
    sub = claims.get("sub")
    return str(sub).strip() if sub else None


def _get_cognito_email(event) -> Optional[str]:
    claims = _get_cognito_claims(event)

    # Most common
    email = claims.get("email")
    if email:
        return str(email).strip()

    # Fallback: sometimes email is used as username
    username = claims.get("cognito:username")
    if username and "@" in str(username):
        return str(username).strip()

    return None


def _get_email_from_cognito(user_sub: str) -> Optional[str]:
    """
    Look up user email from Cognito using their sub (user ID).
    This is needed when using Access Tokens which don't contain the email claim.
    """
    if not USER_POOL_ID:
        print("USER_POOL_ID not set; cannot look up email from Cognito.")
        return None

    try:
        # List users with filter by sub
        response = cognito.list_users(
            UserPoolId=USER_POOL_ID,
            Filter=f'sub = "{user_sub}"',
            Limit=1,
        )

        users = response.get("Users", [])
        if not users:
            print(f"No user found with sub: {user_sub}")
            return None

        # Get email from user attributes
        for attr in users[0].get("Attributes", []):
            if attr["Name"] == "email":
                return attr["Value"]

        return None
    except ClientError as e:
        print(f"Failed to get email from Cognito: {e}")
        return None


def _notify_help_seeker_new_offer(
    request_id: str,
    offer_id: str,
    volunteer_id: str,
    volunteer_email: str,
) -> None:
    """
    Notify help seeker if:
      - request exists and has help_seeker_id
      - NotificationSettings says notify_enabled == True (default True)
      - SNS topic ARN exists
    """
    if not SNS_NEW_OFFERS_TOPIC_ARN:
        print("SNS_NEW_OFFERS_TOPIC_ARN not set; skipping notification.")
        return

    # 1) Read request (help_seeker_id + title/urgency)
    try:
        req = requests_table.get_item(Key={"request_id": request_id}).get("Item")
    except ClientError as e:
        print("Failed to read HelpRequests:", str(e))
        return

    if not req:
        print("Help request not found; skipping notification.")
        return

    help_seeker_id = (req.get("help_seeker_id") or "").strip()
    if not help_seeker_id:
        print("help_seeker_id missing in request; skipping notification.")
        return

    # 2) NotificationSettings
    try:
        settings = notif_table.get_item(Key={"user_id": help_seeker_id}).get("Item") or {}
    except ClientError as e:
        print("Failed to read NotificationSettings:", str(e))
        settings = {}

    notify_enabled = bool(settings.get("notify_enabled", True))
    if not notify_enabled:
        print("Notifications disabled for user:", help_seeker_id)
        return

    title = req.get("title", "-")
    urgency = req.get("urgency", "-")

    payload = {
        "type": "NEW_OFFER",
        "requestId": request_id,
        "offerId": offer_id,
        "volunteerId": volunteer_id,
        "volunteerEmail": volunteer_email,
        "title": title,
        "urgency": urgency,
    }

    message_text = (
        "You received a new volunteer offer in HelpConnect.\n\n"
        f"Title: {title}\n"
        f"Urgency: {urgency}\n"
        f"Volunteer: {volunteer_email}\n"
        f"Request ID: {request_id}\n"
        f"Offer ID: {offer_id}\n\n"
        "Details (JSON):\n"
        f"{json.dumps(payload, default=str)}"
    )

    try:
        sns.publish(
            TopicArn=SNS_NEW_OFFERS_TOPIC_ARN,
            Subject="HelpConnect: New volunteer offer",
            Message=message_text,
        )
        print("SNS published to:", SNS_NEW_OFFERS_TOPIC_ARN)
    except ClientError as e:
        print("SNS publish failed:", str(e))


def lambda_handler(event, context):
    try:
        # CORS preflight
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        volunteer_sub = _get_cognito_sub(event)
        if not volunteer_sub:
            return _build_response(401, {"message": "Unauthorized: missing user sub"})

        # ✅ Try to get email from JWT claims first, then fall back to Cognito lookup
        volunteer_email = _get_cognito_email(event)
        if not volunteer_email:
            volunteer_email = _get_email_from_cognito(volunteer_sub)
        if not volunteer_email:
            volunteer_email = "unknown"

        # Parse request body
        body_raw = event.get("body") or "{}"
        if isinstance(body_raw, str):
            try:
                body = json.loads(body_raw)
            except json.JSONDecodeError:
                return _build_response(400, {"message": "Request body is not valid JSON."})
        elif isinstance(body_raw, dict):
            body = body_raw
        else:
            return _build_response(400, {"message": "Unsupported body format."})

        request_id = body.get("requestId") or body.get("request_id")
        note = body.get("note", "")
        estimated_arrival_minutes = body.get("estimatedArrivalMinutes", 0)

        if not request_id:
            return _build_response(400, {"message": "requestId is required.", "receivedBody": body})

        try:
            eta_int = int(estimated_arrival_minutes)
        except (ValueError, TypeError):
            eta_int = 0

        offer_id = str(uuid.uuid4())
        created_at = datetime.utcnow().isoformat() + "Z"

        item = {
            "offer_id": offer_id,
            "request_id": request_id,
            "volunteer_id": volunteer_sub,
            "volunteer_email": volunteer_email,  # ✅ store email
            "note": note,
            "estimated_arrival_minutes": eta_int,
            "created_at": created_at,
            "status": "PENDING",
        }

        # Write offer
        try:
            offers_table.put_item(Item=item)
        except ClientError as e:
            return _build_response(500, {"message": "Failed to save offer", "error": str(e)})

        # Notify help seeker (best-effort)
        try:
            _notify_help_seeker_new_offer(
                request_id=request_id,
                offer_id=offer_id,
                volunteer_id=volunteer_sub,
                volunteer_email=volunteer_email,
            )
        except Exception as e:
            print("Notification error (ignored):", str(e))

        return _build_response(
            201,
            {
                "message": "Offer created",
                "offer_id": offer_id,
                "request_id": request_id,
                "volunteer_id": volunteer_sub,
                "volunteer_email": volunteer_email,
            },
        )

    except Exception as e:
        return _build_response(500, {"message": "Internal server error", "error": str(e)})