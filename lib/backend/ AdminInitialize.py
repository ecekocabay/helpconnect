import json
import os
import boto3

AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
dynamodb = boto3.client("dynamodb", region_name=AWS_REGION)

HELP_REQUESTS_TABLE = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
OFFERS_TABLE = os.environ.get("OFFERS_TABLE_NAME", "HelpOffers")
NOTIF_TABLE = os.environ.get("NOTIF_TABLE_NAME", "NotificationSettings")


def _resp(code: int, body: dict):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }


def _get_claims(event) -> dict:
    rc = event.get("requestContext") or {}
    auth = rc.get("authorizer") or {}

    jwt = auth.get("jwt")
    if isinstance(jwt, dict):
        claims = jwt.get("claims")
        if isinstance(claims, dict):
            return claims

    claims = auth.get("claims")
    if isinstance(claims, dict):
        return claims

    return {}


def _groups_to_list(groups):
    # groups can be: ["Admin"], "Admin", "Admin,Other", or "['Admin']"
    if not groups:
        return []
    if isinstance(groups, list):
        return [str(g).strip() for g in groups]

    s = str(groups).strip()

    # handle strings that look like JSON list
    if s.startswith("[") and s.endswith("]"):
        try:
            arr = json.loads(s.replace("'", '"'))
            if isinstance(arr, list):
                return [str(g).strip() for g in arr]
        except:
            # fallback: strip brackets and split
            s = s[1:-1].replace('"', "").replace("'", "")

    return [g.strip() for g in s.split(",") if g.strip()]


def _is_admin(event) -> bool:
    claims = _get_claims(event)
    groups = _groups_to_list(claims.get("cognito:groups"))
    # ✅ Your group name is Admin (capital A)
    return "Admin" in groups


def lambda_handler(event, context):
    # CORS preflight
    if (event.get("httpMethod") == "OPTIONS") or (
        (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
    ):
        return _resp(200, {"message": "OK"})

    if not _is_admin(event):
        return _resp(403, {"message": "Forbidden: admin only"})

    tables = [HELP_REQUESTS_TABLE, OFFERS_TABLE, NOTIF_TABLE]
    results = {}

    for t in tables:
        try:
            info = dynamodb.describe_table(TableName=t)
            results[t] = {
                "status": "OK",
                "tableStatus": info["Table"]["TableStatus"],
                "itemCount": info["Table"].get("ItemCount"),
            }
        except Exception as e:
            results[t] = {"status": "ERROR", "error": str(e)}

    return _resp(200, {"message": "Initialize check complete", "tables": results})