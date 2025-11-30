import json
from typing import Any, Dict
from ..services.dynamodb_service import DynamoDbService
from ..utils.response_builder import build_response

dynamo_service = DynamoDbService()

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for volunteers offering help.

    Expected JSON body:
    {
      "requestId": "abcd-123",
      "volunteerId": "vol-789"
    }
    """
    try:
        # Parse body
        if "body" not in event or not event["body"]:
            return build_response(400, {"message": "Missing request body"})

        try:
            body = json.loads(event["body"])
        except:
            return build_response(400, {"message": "Invalid JSON"})

        request_id = body.get("requestId")
        volunteer_id = body.get("volunteerId")

        if not request_id or not volunteer_id:
            return build_response(
                400,
                {"message": "requestId and volunteerId are required"}
            )

        # Add offer
        updated_item = dynamo_service.add_offer_to_request(
            request_id=request_id,
            volunteer_id=volunteer_id,
        )

        return build_response(
            200,
            {
                "message": "Offer added successfully",
                "request": updated_item,
            }
        )

    except Exception as e:
        return build_response(
            500,
            {"message": "Internal server error", "error": str(e)}
        )