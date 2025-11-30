import json
import os
import uuid
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

# ---- DynamoDB setup ----
dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("OFFERS_TABLE_NAME", "HelpOffers")
table = dynamodb.Table(TABLE_NAME)


def _build_response(status_code: int, body):
    """
    Helper to return a proper API Gateway Lambda Proxy response.
    """
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


def lambda_handler(event, context):
    """
    Create a volunteer offer for a given help request.

    Expected JSON body:

    {
      "requestId": "<HELP_REQUEST_ID>",
      "volunteerId": "<VOLUNTEER_ID>",
      "note": "I can help...",
      "estimatedArrivalMinutes": 15
    }
    """

    try:
        # ---- Debug print (helpful if something goes wrong) ----
        print("Incoming event:", json.dumps(event))

        body_raw = event.get("body") or "{}"

        # body may be a string (normal) or already a dict (some tests)
        if isinstance(body_raw, str):
            try:
                body = json.loads(body_raw)
            except json.JSONDecodeError:
                return _build_response(
                    400, {"message": "Request body is not valid JSON."}
                )
        elif isinstance(body_raw, dict):
            body = body_raw
        else:
            return _build_response(
                400, {"message": "Unsupported body format."}
            )

        request_id = body.get("requestId")
        volunteer_id = body.get("volunteerId")
        note = body.get("note", "")
        estimated_arrival_minutes = body.get("estimatedArrivalMinutes", 0)

        # ---- Basic validation ----
        if not request_id or not volunteer_id:
            return _build_response(
                400,
                {
                    "message": "requestId and volunteerId are required fields.",
                    "receivedBody": body,
                },
            )

        try:
            eta_int = int(estimated_arrival_minutes)
        except (ValueError, TypeError):
            eta_int = 0

        offer_id = str(uuid.uuid4())
        created_at = datetime.utcnow().isoformat() + "Z"

        item = {
            "offer_id": offer_id,
            # 👇 This links offer to request
            "request_id": request_id,
            "volunteer_id": volunteer_id,
            "note": note,
            "estimated_arrival_minutes": eta_int,
            "created_at": created_at,
        }

        # ---- Write to DynamoDB ----
        try:
            table.put_item(Item=item)
        except ClientError as e:
            print("DynamoDB put_item error:", e)
            return _build_response(
                500,
                {
                    "message": "Failed to save offer to DynamoDB",
                    "error": str(e),
                },
            )

        return _build_response(
            201,
            {
                "message": "Offer created",
                "offer_id": offer_id,
                "request_id": request_id,
            },
        )

    except Exception as e:
        print("Unhandled exception in OfferHelp:", e)
        return _build_response(
            500,
            {"message": "Internal server error while creating offer", "error": str(e)},
        )