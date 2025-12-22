import json
import os
import boto3

s3 = boto3.client("s3")

def _resp(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "OPTIONS,GET"
        },
        "body": json.dumps(body)
    }

def lambda_handler(event, context):
    try:
        bucket = os.environ["BUCKET_NAME"]

        qs = event.get("queryStringParameters") or {}
        key = qs.get("key")

        if not key:
            return _resp(400, {"message": "key is required"})

        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket, "Key": key},
            ExpiresIn=300
        )

        return _resp(200, {"viewUrl": url})
    except Exception as e:
        return _resp(500, {"message": str(e)})