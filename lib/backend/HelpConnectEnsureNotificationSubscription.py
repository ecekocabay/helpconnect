import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

NOTIF_TABLE = os.environ.get("NOTIF_TABLE_NAME", "NotificationSettings")
table = dynamodb.Table(NOTIF_TABLE)

TOPIC_NEW_REQUESTS = os.environ.get("SNS_NEW_REQUESTS_TOPIC_ARN", "")
TOPIC_NEW_OFFERS = os.environ.get("SNS_NEW_OFFERS_TOPIC_ARN", "")


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


def _get_cognito_claims(event) -> dict:
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}
    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        return jwt.get("claims") or {}
    return auth.get("claims") or {}


def _get_cognito_sub(event) -> str | None:
    return _get_cognito_claims(event).get("sub")


def _topic_for_role(role: str) -> str | None:
    r = (role or "").strip().upper()
    if r == "VOLUNTEER":
        return TOPIC_NEW_REQUESTS if TOPIC_NEW_REQUESTS else None
    if r == "HELP_SEEKER":
        return TOPIC_NEW_OFFERS if TOPIC_NEW_OFFERS else None
    return None


def lambda_handler(event, context):
    try:
        # CORS
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        user_id = _get_cognito_sub(event)
        if not user_id:
            return _build_response(401, {"message": "Unauthorized: missing user sub"})

        # fetch settings
        try:
            resp = table.get_item(Key={"user_id": user_id})
            item = resp.get("Item") or {}
        except ClientError as e:
            return _build_response(500, {"message": "DynamoDB error", "error": str(e)})

        notify_enabled = bool(item.get("notify_enabled", True))
        if not notify_enabled:
            return _build_response(200, {"message": "Notifications disabled; subscription skipped"})

        email = (item.get("email") or "").strip()
        role = (item.get("role") or "").strip().upper()

        if not email:
            return _build_response(400, {"message": "No email stored for this user. Update settings with email."})
        if not role:
            return _build_response(400, {"message": "No role stored for this user. Update settings with role."})

        topic_arn = _topic_for_role(role)
        if not topic_arn:
            return _build_response(500, {"message": f"Topic ARN missing for role={role}"})

        # Check if already subscribed (avoid duplicates)
        try:
            next_token = None
            already = False
            while True:
                kwargs = {"TopicArn": topic_arn}
                if next_token:
                    kwargs["NextToken"] = next_token
                subs = sns.list_subscriptions_by_topic(**kwargs)

                for s in subs.get("Subscriptions", []):
                    if (s.get("Protocol") == "email") and (s.get("Endpoint") == email):
                        already = True
                        break
                if already:
                    break

                next_token = subs.get("NextToken")
                if not next_token:
                    break

            if already:
                return _build_response(200, {"message": "Already subscribed", "email": email, "topicArn": topic_arn})

            # Subscribe (SNS will send confirmation email once)
            sub_resp = sns.subscribe(
                TopicArn=topic_arn,
                Protocol="email",
                Endpoint=email,
                ReturnSubscriptionArn=True,
            )
            return _build_response(
                200,
                {
                    "message": "Subscription requested. Confirm the email from AWS SNS to activate.",
                    "email": email,
                    "topicArn": topic_arn,
                    "subscriptionArn": sub_resp.get("SubscriptionArn"),
                },
            )
        except ClientError as e:
            return _build_response(500, {"message": "SNS error", "error": str(e)})

    except Exception as e:
        return _build_response(500, {"message": "Internal server error", "error": str(e)})