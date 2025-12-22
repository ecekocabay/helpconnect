import json
import os
from datetime import datetime

import boto3
from botocore.exceptions import ClientError


def _clean_table_name(value: str) -> str:
    """
    DynamoDB TableName must match: [a-zA-Z0-9_.-]+
    Removes common invisible chars from console copy/paste.
    """
    if value is None:
        return ""

    v = value.strip()

    invisible = [
        "\u200b",  # zero width space
        "\u200c",
        "\u200d",
        "\ufeff",  # BOM
        "\u00a0",  # non-breaking space
        "\r",
        "\n",
        "\t",
    ]
    for ch in invisible:
        v = v.replace(ch, "")

    return v


AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
dynamodb = boto3.client("dynamodb", region_name=AWS_REGION)

HELP_REQUESTS_TABLE = _clean_table_name(os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests"))
OFFERS_TABLE = _clean_table_name(os.environ.get("OFFERS_TABLE_NAME", "HelpOffers"))


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
    """
    HTTP API v2 JWT authorizer:
      event.requestContext.authorizer.jwt.claims.sub
    REST API v1 Cognito authorizer:
      event.requestContext.authorizer.claims.sub
    """
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}

    # HTTP API v2
    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        claims = jwt.get("claims") or {}
        sub = claims.get("sub")
        if sub:
            return sub

    # REST API v1
    claims = auth.get("claims") or {}
    return claims.get("sub")


def lambda_handler(event, context):
    """
    POST /accept-offer
    Body:
      { "requestId": "...", "offerId": "..." }

    Behavior:
      - Only the help seeker (owner of the request) can accept an offer
      - Atomically sets HelpRequests.status=IN_PROGRESS and marks Offer as ACCEPTED
      - Returns 409 if already accepted or request isn't OPEN/Open
    """
    try:
        print("Incoming event:", json.dumps(event))

        # Debug: show exact table names we will use (repr reveals hidden chars)
        print("AWS_REGION:", AWS_REGION)
        print("HELP_REQUESTS_TABLE repr:", repr(HELP_REQUESTS_TABLE))
        print("OFFERS_TABLE repr:", repr(OFFERS_TABLE))

        if not HELP_REQUESTS_TABLE or not OFFERS_TABLE:
            return _build_response(
                500,
                {
                    "message": "Server misconfigured: table env vars are empty after cleaning",
                    "HELP_REQUESTS_TABLE": repr(HELP_REQUESTS_TABLE),
                    "OFFERS_TABLE": repr(OFFERS_TABLE),
                },
            )

        # CORS preflight
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        help_seeker_sub = _get_cognito_sub(event)
        if not help_seeker_sub:
            return _build_response(401, {"message": "Unauthorized: missing user sub"})

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

        request_id = body.get("requestId") or body.get("request_id")
        offer_id = body.get("offerId") or body.get("offer_id")

        if not request_id or not offer_id:
            return _build_response(400, {"message": "requestId and offerId are required"})

        now = datetime.utcnow().isoformat() + "Z"

        # 1) Read offer (to get volunteer_id)
        offer_resp = dynamodb.get_item(
            TableName=OFFERS_TABLE,
            Key={
                "request_id": {"S": request_id},
                "offer_id": {"S": offer_id},
            },
        )
        offer_item = offer_resp.get("Item")
        if not offer_item:
            return _build_response(404, {"message": "Offer not found for this request"})

        volunteer_id = offer_item.get("volunteer_id", {}).get("S")
        if not volunteer_id:
            return _build_response(500, {"message": "Offer missing volunteer_id"})

        # 2) Read request (verify owner)
        req_resp = dynamodb.get_item(
            TableName=HELP_REQUESTS_TABLE,
            Key={"request_id": {"S": request_id}},
        )
        req_item = req_resp.get("Item")
        if not req_item:
            return _build_response(404, {"message": "Help request not found"})

        owner_id = req_item.get("help_seeker_id", {}).get("S")
        if owner_id != help_seeker_sub:
            return _build_response(403, {"message": "Forbidden: not your request"})

        # Optional: read status for clearer errors
        current_status = (req_item.get("status", {}) or {}).get("S")
        current_accepted = (req_item.get("accepted_offer_id", {}) or {}).get("S")

        # 3) Atomic update: request + offer
        try:
            dynamodb.transact_write_items(
                TransactItems=[
                    {
                        "Update": {
                            "TableName": HELP_REQUESTS_TABLE,
                            "Key": {"request_id": {"S": request_id}},
                            "UpdateExpression": (
                                "SET #s = :inprog, "
                                "accepted_offer_id = :oid, "
                                "accepted_volunteer_id = :vid, "
                                "accepted_at = :now"
                            ),
                            # ✅ FIX: accept both "Open" and "OPEN"
                            "ConditionExpression": (
                                "(attribute_not_exists(accepted_offer_id)) AND "
                                "(attribute_not_exists(#s) OR #s = :open1 OR #s = :open2)"
                            ),
                            "ExpressionAttributeNames": {"#s": "status"},
                            "ExpressionAttributeValues": {
                                ":inprog": {"S": "IN_PROGRESS"},
                                ":open1": {"S": "Open"},
                                ":open2": {"S": "OPEN"},
                                ":oid": {"S": offer_id},
                                ":vid": {"S": volunteer_id},
                                ":now": {"S": now},
                            },
                        }
                    },
                    {
                        "Update": {
                            "TableName": OFFERS_TABLE,
                            "Key": {
                                "request_id": {"S": request_id},
                                "offer_id": {"S": offer_id},
                            },
                            "UpdateExpression": "SET #st = :acc, accepted_at = :now",
                            "ExpressionAttributeNames": {"#st": "status"},
                            "ExpressionAttributeValues": {
                                ":acc": {"S": "ACCEPTED"},
                                ":now": {"S": now},
                            },
                        }
                    },
                ]
            )

        except ClientError as e:
            if e.response.get("Error", {}).get("Code") == "TransactionCanceledException":
                # clearer info for debugging (safe enough)
                return _build_response(
                    409,
                    {
                        "message": "Request already accepted or not OPEN/Open",
                        "requestStatus": current_status,
                        "acceptedOfferId": current_accepted,
                    },
                )
            raise

        return _build_response(
            200,
            {
                "message": "Offer accepted",
                "requestId": request_id,
                "offerId": offer_id,
                "volunteerId": volunteer_id,
                "status": "IN_PROGRESS",
            },
        )

    except Exception as e:
        print("Unhandled exception:", str(e))
        return _build_response(500, {"message": "Internal server error", "error": str(e)})