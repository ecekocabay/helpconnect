import json
import os
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
    Get a single help request by ID.

    Route: GET /help-requests/{id}
    Path parameter name: id
    """
    try:
        path_params = event.get("pathParameters") or {}
        request_id = path_params.get("id")

        if not request_id:
            return _build_response(
                400, {"message": "Missing path parameter: id"}
            )

        try:
            resp = table.get_item(Key={"request_id": request_id})
            item = resp.get("Item")
        except ClientError as e:
            return _build_response(
                500,
                {"message": "Failed to get item from DynamoDB", "error": str(e)},
            )

        if not item:
            return _build_response(
                404, {"message": f"Help request {request_id} not found"}
            )

        return _build_response(200, item)

    except Exception as e:
        return _build_response(
            500, {"message": "Internal server error", "error": str(e)}
        )