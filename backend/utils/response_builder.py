import json
from typing import Any, Dict


def build_response(status_code: int, body: Any) -> Dict[str, Any]:
    """
    Build a standard API Gateway-compatible HTTP response.
    """
    # If body is not a string, convert to JSON string
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