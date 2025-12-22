import os
import json
import boto3
from datetime import datetime, timezone

AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
sns = boto3.client("sns", region_name=AWS_REGION)
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)

SNS_NEW_REQUESTS_TOPIC_ARN = os.environ.get("SNS_NEW_REQUESTS_TOPIC_ARN", "")
SNS_NEW_OFFERS_TOPIC_ARN = os.environ.get("SNS_NEW_OFFERS_TOPIC_ARN", "")
NOTIF_TABLE_NAME = os.environ.get("NOTIF_TABLE_NAME", "")

notif_table = dynamodb.Table(NOTIF_TABLE_NAME) if NOTIF_TABLE_NAME else None


def _subscribe_email(topic_arn: str, email: str):
    if not topic_arn:
        return None
    resp = sns.subscribe(
        TopicArn=topic_arn,
        Protocol="email",
        Endpoint=email,
        ReturnSubscriptionArn=True,  # will still be "pending confirmation" for email until user clicks
    )
    return resp.get("SubscriptionArn")


def lambda_handler(event, context):
    """
    Cognito Post Confirmation trigger event.
    event['request']['userAttributes'] contains: sub, email, etc.
    """
    attrs = (event.get("request") or {}).get("userAttributes") or {}
    user_sub = attrs.get("sub")
    email = attrs.get("email")

    print("PostConfirmation event:", json.dumps(event))

    # If email isn't present, we can't subscribe
    if not user_sub or not email:
        print("Missing sub/email; skipping SNS subscribe")
        return event

    # Subscribe user email to topics (best-effort)
    new_req_sub_arn = None
    new_offer_sub_arn = None

    try:
        new_req_sub_arn = _subscribe_email(SNS_NEW_REQUESTS_TOPIC_ARN, email)
        print("Subscribed to NEW_REQUESTS:", new_req_sub_arn)
    except Exception as e:
        print("Subscribe NEW_REQUESTS failed:", str(e))

    try:
        new_offer_sub_arn = _subscribe_email(SNS_NEW_OFFERS_TOPIC_ARN, email)
        print("Subscribed to NEW_OFFERS:", new_offer_sub_arn)
    except Exception as e:
        print("Subscribe NEW_OFFERS failed:", str(e))

    # Optional: save settings in DynamoDB
    if notif_table:
        now = datetime.now(timezone.utc).isoformat()
        try:
            notif_table.put_item(
                Item={
                    "user_id": user_sub,          # <- keep consistent with your other Lambdas
                    "email": email,
                    "notify_enabled": True,
                    "created_at": now,
                    "sns_new_requests_sub_arn": new_req_sub_arn,
                    "sns_new_offers_sub_arn": new_offer_sub_arn,
                }
            )
        except Exception as e:
            print("Failed to write NotificationSettings:", str(e))

    return event