import json
from typing import Any, Dict

from ..models.help_request import HelpRequest
from ..services.dynamodb_service import DynamoDbService
from ..utils.response_builder import build_response


dynamo_service = DynamoDbService()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler to create a new help request.

    Expected input (JSON body):

    {
      "helpSeekerId": "USER-ID-FROM-COGNITO-OR-MOCK",
      "title": "Urgent Blood Donation Needed",
      "description": "O+ blood required within 4 hours at City Hospital.",
      "category": "Medical",
      "urgency": "High",
      "location": "City Hospital",
      "imageKey": "optional-s3-object-key"
    }
    """
    try:
        # Parse body
        if "body" not in event or event["body"] is None:
            return build_response(400, {"message": "Missing request body"})

        try:
            body = json.loads(event["body"])
        except json.JSONDecodeError:
            return build_response(400, {"message": "Invalid JSON in body"})

        # Extract and validate required fields
        required_fields = ["helpSeekerId", "title", "description", "category", "urgency", "location"]
        missing = [f for f in required_fields if f not in body or not body[f]]

        if missing:
            return build_response(
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

        # Create HelpRequest entity
        help_request = HelpRequest.create_new(
            help_seeker_id=help_seeker_id,
            title=title,
            description=description,
            category=category,
            urgency=urgency,
            location=location,
            image_key=image_key,
        )

        # Save to DynamoDB
        item = dynamo_service.save_help_request(help_request)

        # Build success response
        return build_response(
            201,
            {
                "message": "Help request created successfully",
                "requestId": item["request_id"],
            },
        )

    except Exception as e:
        # In real app, log the error (e.g. to CloudWatch)
        return build_response(
            500,
            {"message": "Internal server error", "error": str(e)},
        )