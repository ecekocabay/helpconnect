import json
import os
import boto3

AWS_REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "eu-central-1"
ddb = boto3.resource("dynamodb", region_name=AWS_REGION)

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
    """
    Works for BOTH:
    - HTTP API JWT authorizer: requestContext.authorizer.jwt.claims
    - REST API / older: requestContext.authorizer.claims
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


def _groups_to_list(groups_val):
    """
    Normalize cognito:groups to list[str].
    Handles:
      - ["Admin","X"]
      - "Admin"
      - "Admin,X"
      - '["Admin","X"]'
      - "['Admin']"
    """
    if groups_val is None:
        return []

    if isinstance(groups_val, list):
        return [str(x).strip() for x in groups_val if str(x).strip()]

    s = str(groups_val).strip()
    if not s:
        return []

    # JSON string list
    if s.startswith("[") and s.endswith("]"):
        try:
            parsed = json.loads(s)
            if isinstance(parsed, list):
                return [str(x).strip() for x in parsed if str(x).strip()]
        except Exception:
            pass
        # python list string
        s2 = s[1:-1].replace('"', "").replace("'", "")
        return [p.strip() for p in s2.split(",") if p.strip()]

    # comma-separated string
    if "," in s:
        return [p.strip() for p in s.split(",") if p.strip()]

    return [s]


def _is_admin(event) -> bool:
    claims = _get_claims(event)
    groups = _groups_to_list(claims.get("cognito:groups"))
    # ✅ your group name is exactly "Admin"
    return "Admin" in groups


def lambda_handler(event, context):
    # CORS preflight
    if (event.get("httpMethod") == "OPTIONS") or (
        (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
    ):
        return _resp(200, {"message": "OK"})

    if not _is_admin(event):
        # helpful debug (remove later if you want)
        claims = _get_claims(event)
        return _resp(
            403,
            {
                "message": "Forbidden: admin only",
                "debug": {
                    "groupsRaw": claims.get("cognito:groups"),
                },
            },
        )

    # Query params: ?table=HelpRequests&limit=25
    qs = event.get("queryStringParameters") or {}
    table_name = (qs.get("table") or "HelpRequests").strip()

    try:
        limit = int(qs.get("limit") or "25")
    except Exception:
        limit = 25
    limit = max(1, min(limit, 100))

    table_map = {
        "HelpRequests": ddb.Table(HELP_REQUESTS_TABLE),
        "HelpOffers": ddb.Table(OFFERS_TABLE),
        "NotificationSettings": ddb.Table(NOTIF_TABLE),
    }
    if table_name not in table_map:
        return _resp(400, {"message": "Invalid table", "allowed": list(table_map.keys())})

    table = table_map[table_name]

    # Optional pagination: &lastKey={"request_id":"..."}  (URL-encoded)
    last_key_raw = qs.get("lastKey")
    scan_kwargs = {"Limit": limit}

    if last_key_raw:
        try:
            scan_kwargs["ExclusiveStartKey"] = json.loads(last_key_raw)
        except Exception:
            return _resp(400, {"message": "lastKey must be valid JSON"})

    try:
        res = table.scan(**scan_kwargs)
        return _resp(
            200,
            {
                "table": table_name,
                "count": len(res.get("Items", [])),
                "items": res.get("Items", []),
                "lastKey": res.get("LastEvaluatedKey"),
            },
        )
    except Exception as e:
        return _resp(500, {"message": "Scan failed", "error": str(e)})