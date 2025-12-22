import json
import os
import boto3
from datetime import datetime, timezone
import base64

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
    Supports:
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
    Normalize cognito:groups to a list[str].
    Handles:
      - ["Admin", "X"]
      - "Admin"
      - "Admin,X"
      - "['Admin']"
      - '["Admin","X"]'
    """
    if not groups_val:
        return []

    if isinstance(groups_val, list):
        return [str(x).strip() for x in groups_val if str(x).strip()]

    s = str(groups_val).strip()
    if not s:
        return []

    # Looks like a list string
    if s.startswith("[") and s.endswith("]"):
        # try JSON
        try:
            parsed = json.loads(s.replace("'", '"'))
            if isinstance(parsed, list):
                return [str(x).strip() for x in parsed if str(x).strip()]
        except Exception:
            pass

        # fallback: strip brackets and split
        s2 = s[1:-1].replace('"', "").replace("'", "")
        return [p.strip() for p in s2.split(",") if p.strip()]

    # comma-separated
    if "," in s:
        return [p.strip() for p in s.split(",") if p.strip()]

    return [s]


def _is_admin(event) -> (bool, dict):
    claims = _get_claims(event)
    groups_raw = claims.get("cognito:groups")
    groups = _groups_to_list(groups_raw)
    ok = ("Admin" in groups)  # ✅ your group name is "Admin"
    return ok, {"groupsRaw": groups_raw, "groupsParsed": groups}


# Restrict what admin is allowed to change (recommended)
ALLOWED_FIELDS = {
    "HelpRequests": {"status", "title", "description", "urgency", "category", "location"},
    "HelpOffers": {"status", "note", "estimated_arrival_minutes"},
    "NotificationSettings": {"notify_enabled", "email"},
}


def _read_json_body(event):
    body = event.get("body")
    if body is None:
        return {}

    # API Gateway can pass base64 body
    if event.get("isBase64Encoded") is True and isinstance(body, str):
        try:
            body = base64.b64decode(body).decode("utf-8")
        except Exception:
            return None

    if isinstance(body, dict):
        return body

    if isinstance(body, str):
        body = body.strip()
        if not body:
            return {}
        try:
            return json.loads(body)
        except Exception:
            return None

    return None


def lambda_handler(event, context):
    # Helpful debug in CloudWatch
    method_v1 = event.get("httpMethod")
    method_v2 = (event.get("requestContext") or {}).get("http", {}).get("method")
    print("method_v1:", method_v1, "method_v2:", method_v2)
    print("path:", event.get("rawPath") or event.get("path"))

    # CORS
    if (method_v1 == "OPTIONS") or (method_v2 == "OPTIONS"):
        return _resp(200, {"message": "OK"})

    # Allow PATCH or POST (in case API Gateway route was created as POST by mistake)
    if method_v1 and method_v1 not in ["PATCH", "POST"]:
        return _resp(405, {"message": "Method not allowed", "allowed": ["PATCH", "POST"]})
    if method_v2 and method_v2 not in ["PATCH", "POST"]:
        return _resp(405, {"message": "Method not allowed", "allowed": ["PATCH", "POST"]})

    ok, dbg = _is_admin(event)
    if not ok:
        return _resp(
            403,
            {
                "message": "Forbidden: admin only",
                "debug": dbg,
            },
        )

    body = _read_json_body(event)
    if body is None:
        return _resp(400, {"message": "Invalid JSON body"})

    table_name = body.get("table")   # "HelpRequests" | "HelpOffers" | "NotificationSettings"
    key = body.get("key")            # dict PK/SK depending on table
    updates = body.get("updates")    # dict of field->value

    if table_name not in ALLOWED_FIELDS:
        return _resp(400, {"message": "Invalid table", "allowed": list(ALLOWED_FIELDS.keys())})
    if not isinstance(key, dict) or not isinstance(updates, dict) or not updates:
        return _resp(400, {"message": "key and updates are required"})

    # Validate allowed fields
    allowed = ALLOWED_FIELDS[table_name]
    bad = [k for k in updates.keys() if k not in allowed]
    if bad:
        return _resp(
            400,
            {
                "message": "Some fields are not allowed to be modified",
                "notAllowed": bad,
                "allowed": sorted(list(allowed)),
            },
        )

    # Resolve DynamoDB table + key format
    if table_name == "HelpRequests":
        table = ddb.Table(HELP_REQUESTS_TABLE)
        if "request_id" not in key:
            return _resp(400, {"message": "HelpRequests key must include request_id"})
        ddb_key = {"request_id": key["request_id"]}

    elif table_name == "HelpOffers":
        table = ddb.Table(OFFERS_TABLE)
        if "request_id" not in key or "offer_id" not in key:
            return _resp(400, {"message": "HelpOffers key must include request_id and offer_id"})
        ddb_key = {"request_id": key["request_id"], "offer_id": key["offer_id"]}

    else:
        table = ddb.Table(NOTIF_TABLE)
        if "user_id" not in key:
            return _resp(400, {"message": "NotificationSettings key must include user_id"})
        ddb_key = {"user_id": key["user_id"]}

    # Build update expression safely
    expr_names = {}
    expr_values = {}
    sets = []

    for i, (field, value) in enumerate(updates.items()):
        n = f"#f{i}"
        v = f":v{i}"
        expr_names[n] = field
        expr_values[v] = value
        sets.append(f"{n} = {v}")

    # Always store audit fields
    now = datetime.now(timezone.utc).isoformat()
    expr_names["#updatedAt"] = "admin_updated_at"
    expr_values[":updatedAt"] = now
    sets.append("#updatedAt = :updatedAt")

    try:
        res = table.update_item(
            Key=ddb_key,
            UpdateExpression="SET " + ", ".join(sets),
            ExpressionAttributeNames=expr_names,
            ExpressionAttributeValues=expr_values,
            ReturnValues="ALL_NEW",
        )
        return _resp(200, {"message": "Updated", "item": res.get("Attributes")})
    except Exception as e:
        return _resp(500, {"message": "Update failed", "error": str(e)})