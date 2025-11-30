import json
import os
import uuid
from datetime import datetime

import boto3
from botocore.exceptions import ClientError


dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
table = dynamodb.Table(TABLE_NAME)


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


def lambda_handler(event, context):
    """
    Create a new help request.

    Expected JSON body:
    {
      "helpSeekerId": "user-123",
      "title": "Urgent Blood Donation Needed",
      "description": "O+ blood required within 4 hours at City Hospital.",
      "category": "Medical",
      "urgency": "High",
      "location": "City Hospital",
      "imageKey": "optional-s3-key-or-null"
    }
    """
    try:
        # Parse body
        if "body" not in event or not event["body"]:
            return _build_response(400, {"message": "Missing request body"})

        try:
            body = json.loads(event["body"])
        except json.JSONDecodeError:
            return _build_response(400, {"message": "Invalid JSON in body"})

        # Required fields
        required = ["helpSeekerId", "title", "description", "category", "urgency", "location"]
        missing = [f for f in required if not body.get(f)]

        if missing:
            return _build_response(
                400,
                {"message": f"Missing required fields: {', '.join(missing)}"},
            )

        help_seeker_id = body["helpSeekerId"]
        title = body["title"]
        description = body["description"]
        category = body["category"]
        urgency = body["urgency"]
        location = body["location"]
        image_key = body.get("imageKey")

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
            "status": "Open",
            "created_at": now,
            "offers": [],
        }

        # Save to DynamoDB
        try:
            table.put_item(Item=item)
        except ClientError as e:
            return _build_response(
                500,
                {"message": "Failed to save help request", "error": str(e)},
            )

        return _build_response(
            201,
            {
                "message": "Help request created successfully",
                "requestId": request_id,
            },
        )

    except Exception as e:
        return _build_response(
            500,
            {"message": "Internal server error", "error": str(e)},
        )