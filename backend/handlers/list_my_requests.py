from typing import Any, Dict
from ..services.dynamodb_service import DynamoDbService
from ..utils.response_builder import build_response

dynamo_service = DynamoDbService()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler to list help requests for a specific Help Seeker.

    Expected:
      - helpSeekerId either in queryStringParameters or later from auth context.

    Example query:
      GET /my-requests?helpSeekerId=user-123
    """
    try:
        qs = event.get("queryStringParameters") or {}
        help_seeker_id = qs.get("helpSeekerId")

        if not help_seeker_id:
            return build_response(
                400,
                {"message": "Missing required query parameter: helpSeekerId"},
            )

        items = dynamo_service.list_help_requests_by_help_seeker(
            help_seeker_id=help_seeker_id,
            limit=100,
        )

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