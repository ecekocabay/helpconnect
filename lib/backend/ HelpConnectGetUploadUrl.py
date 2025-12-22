import os, json, uuid
import boto3
from datetime import datetime

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
        bucket = os.environ["BUCKET_NAME"]
        expires = int(os.environ.get("UPLOAD_URL_EXPIRES_SECONDS", "300"))

        body = json.loads(event.get("body") or "{}")
        request_id = body.get("request_id")  # optional but recommended
        content_type = body.get("content_type", "image/jpeg")

        ext = "png" if content_type == "image/png" else "jpg"
        image_id = str(uuid.uuid4())

        if request_id:
            image_key = f"requests/{request_id}/{image_id}.{ext}"
        else:
            image_key = f"uploads/{image_id}.{ext}"

        upload_url = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": bucket,
                "Key": image_key,
                "ContentType": content_type,
            },
            ExpiresIn=expires,
        )

        return resp(200, {
            "uploadUrl": upload_url,
            "imageKey": image_key,
            "image_id": image_id,
            "content_type": content_type
        })

    except Exception as e:
        return resp(500, {"message": "Failed to create upload URL", "error": str(e)})

    

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