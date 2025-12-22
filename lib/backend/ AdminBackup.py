import json
import os
import boto3
from datetime import datetime, timezone

AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
ddb = boto3.resource("dynamodb", region_name=AWS_REGION)
s3 = boto3.client("s3", region_name=AWS_REGION)

HELP_REQUESTS_TABLE = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
OFFERS_TABLE = os.environ.get("OFFERS_TABLE_NAME", "HelpOffers")
NOTIF_TABLE = os.environ.get("NOTIF_TABLE_NAME", "NotificationSettings")

BACKUP_BUCKET = os.environ.get("BACKUP_BUCKET", "")


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
    """
    Supports:
    - HTTP API JWT authorizer: requestContext.authorizer.jwt.claims
    - REST API / other: requestContext.authorizer.claims
    """
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
    """
    Convert cognito:groups to a clean Python list.
    Possible inputs:
      - ["Admin", "X"]
      - "Admin"
      - "Admin,X"
      - '["Admin","X"]'
    """
    if not groups:
        return []

    # already a list
    if isinstance(groups, list):
        return [str(g).strip() for g in groups if str(g).strip()]

    s = str(groups).strip()
    if not s:
        return []

    # JSON array string?
    if s.startswith("[") and s.endswith("]"):
        try:
            arr = json.loads(s.replace("'", '"'))
            if isinstance(arr, list):
                return [str(g).strip() for g in arr if str(g).strip()]
        except Exception:
            # fallback: strip brackets then split
            s = s[1:-1]

    # comma-separated string
    return [g.strip() for g in s.split(",") if g.strip()]


def _is_admin(event) -> bool:
    claims = _get_claims(event)
    groups = _groups_to_list(claims.get("cognito:groups"))

    # Debug logs (CloudWatch)
    print("claims keys:", list(claims.keys()))
    print("raw cognito:groups:", claims.get("cognito:groups"))
    print("parsed groups:", groups)

    # ✅ strict match: ONLY Admin
    return "Admin" in groups


def _scan_all(table):
    items = []
    kwargs = {}
    while True:
        res = table.scan(**kwargs)
        items.extend(res.get("Items", []))
        lek = res.get("LastEvaluatedKey")
        if not lek:
            break
        kwargs["ExclusiveStartKey"] = lek
    return items


def lambda_handler(event, context):
    # CORS preflight
    if (event.get("httpMethod") == "OPTIONS") or (
        (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
    ):
        return _resp(200, {"message": "OK"})

    if not _is_admin(event):
        return _resp(403, {"message": "Forbidden: Admin group only"})

    if not BACKUP_BUCKET:
        return _resp(500, {"message": "BACKUP_BUCKET env var is missing"})

    now = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    prefix = f"helpconnect-backups/{now}/"

    tables = {
        "HelpRequests": ddb.Table(HELP_REQUESTS_TABLE),
        "HelpOffers": ddb.Table(OFFERS_TABLE),
        "NotificationSettings": ddb.Table(NOTIF_TABLE),
    }

    result = {}

    try:
        for logical_name, table in tables.items():
            items = _scan_all(table)
            key = f"{prefix}{logical_name}.json"

            s3.put_object(
                Bucket=BACKUP_BUCKET,
                Key=key,
                Body=json.dumps(items, default=str).encode("utf-8"),
                ContentType="application/json",
            )

            result[logical_name] = {"count": len(items), "s3Key": key}

        return _resp(
            200,
            {
                "message": "Backup completed",
                "bucket": BACKUP_BUCKET,
                "prefix": prefix,
                "files": result,
            },
        )

    except Exception as e:
        return _resp(500, {"message": "Backup failed", "error": str(e), "partial": result})