from typing import Any, Dict
from ..services.dynamodb_service import DynamoDbService
from ..utils.response_builder import build_response

dynamo_service = DynamoDbService()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler to list all help requests for Volunteers.

    For Stage 2:
      - No query parameters are required.
      - Later we can support filters (category, urgency, location).
    """
    try:
        items = dynamo_service.list_all_help_requests(limit=100)

        # We could do basic sorting by created_at descending here later.
        return build_response(
            200,
            {
                "items": items,
                "count": len(items),
            },
        )
    except Exception as e:
        return build_response(
            500,
            {"message": "Internal server error", "error": str(e)},
        )