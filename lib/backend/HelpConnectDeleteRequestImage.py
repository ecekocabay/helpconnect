import os, json
import boto3

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

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
        delete_from_s3 = os.environ.get("DELETE_FROM_S3", "false").lower() == "true"
        bucket = os.environ.get("BUCKET_NAME")

        path = event.get("pathParameters") or {}
        request_id = path.get("requestId")
        image_id = path.get("imageId")

        if not request_id or not image_id:
            return resp(400, {"message": "Missing path params: requestId/imageId"})

        # Fetch to get imageKey
        existing = table.get_item(Key={"request_id": request_id, "image_id": image_id})
        item = existing.get("Item")
        if not item:
            return resp(404, {"message": "Image not found"})

        image_key = item.get("imageKey")

        # Delete from DynamoDB
        table.delete_item(Key={"request_id": request_id, "image_id": image_id})

        # Optional: delete S3 object
        if delete_from_s3 and bucket and image_key:
            s3.delete_object(Bucket=bucket, Key=image_key)

        return resp(200, {"deleted": True, "request_id": request_id, "image_id": image_id})

    except Exception as e:
        return resp(500, {"message": "Failed to delete image", "error": str(e)})


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