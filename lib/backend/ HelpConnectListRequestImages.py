import os, json
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")

def resp(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Authorization,Content-Type",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        },
        "body": json.dumps(body),
    }

def lambda_handler(event, context):
    try:
        table = dynamodb.Table(os.environ["REQUEST_IMAGES_TABLE"])

        request_id = (event.get("pathParameters") or {}).get("requestId")
        if not request_id:
            return resp(400, {"message": "Missing path param: requestId"})

        out = table.query(
            KeyConditionExpression=Key("request_id").eq(request_id)
        )

        return resp(200, {"images": out.get("Items", [])})

    except Exception as e:
        return resp(500, {"message": "Failed to list images", "error": str(e)})


def resp(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Authorization,Content-Type",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        },
        "body": json.dumps(body),
    }

def get_claim_sub(event):
    # HTTP API JWT authorizer commonly here:
    auth = event.get("requestContext", {}).get("authorizer", {})
    jwt = auth.get("jwt", {})
    claims = jwt.get("claims", {})
    return claims.get("sub")