from typing import Any, Dict
from ..services.dynamodb_service import DynamoDbService
from ..utils.response_builder import build_response

dynamo_service = DynamoDbService()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler to get a single help request by ID.

    Expected path parameter (API Gateway REST pattern):
      GET /help-requests/{id}

    event["pathParameters"] should contain:
      { "id": "REQUEST_ID" }
    """
    try:
        path_params = event.get("pathParameters") or {}
        request_id = path_params.get("id")

        if not request_id:
            return build_response(
                400,
                {"message": "Missing path parameter: id"},
            )

        item = dynamo_service.get_help_request(request_id)

        if not item:
            return build_response(
                404,
                {"message": f"Help request with id {request_id} not found"},
            )

        return build_response(200, item)

    except Exception as e:
        return build_response(
            500,
            {"message": "Internal server error", "error": str(e)},
        )