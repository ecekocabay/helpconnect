import os, json, uuid
import boto3
from datetime import datetime

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

def get_claim_sub(event):
    auth = event.get("requestContext", {}).get("authorizer", {})
    claims = auth.get("jwt", {}).get("claims", {})
    return claims.get("sub")

def lambda_handler(event, context):
    try:
        table = dynamodb.Table(os.environ["REQUEST_IMAGES_TABLE"])

        request_id = (event.get("pathParameters") or {}).get("requestId")
        if not request_id:
            return resp(400, {"message": "Missing path param: requestId"})

        user_sub = get_claim_sub(event)
        if not user_sub:
            return resp(401, {"message": "Unauthorized"})

        body = json.loads(event.get("body") or "{}")
        image_key = body.get("imageKey")
        if not image_key:
            return resp(400, {"message": "Missing body: imageKey"})

        # Hardening: ensure key belongs to this request
        if not image_key.startswith(f"requests/{request_id}/"):
            return resp(400, {"message": "imageKey must start with requests/{requestId}/"})

        image_id = body.get("image_id") or str(uuid.uuid4())
        created_at = datetime.utcnow().isoformat() + "Z"

        table.put_item(Item={
            "request_id": request_id,
            "image_id": image_id,
            "imageKey": image_key,
            "uploadedBy": user_sub,
            "createdAt": created_at,
        })

        return resp(200, {
            "request_id": request_id,
            "image_id": image_id,
            "imageKey": image_key,
            "createdAt": created_at
        })

    except Exception as e:
        return resp(500, {"message": "Failed to attach image", "error": str(e)})


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