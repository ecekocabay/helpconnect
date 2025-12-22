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
        "body": json.dumps(body),
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
    Normalize cognito:groups value to a Python list of strings.
    Handles:
      - ["Admin", "X"]
      - "Admin"
      - "Admin,X"
      - "['Admin']"
      - '["Admin","X"]'
    """
    if groups_val is None:
        return []

    # Already a list
    if isinstance(groups_val, list):
        return [str(x).strip() for x in groups_val if str(x).strip()]

    s = str(groups_val).strip()
    if not s:
        return []

    # Try to parse JSON list string: '["Admin","X"]'
    if (s.startswith("[") and s.endswith("]")):
        try:
            parsed = json.loads(s)
            if isinstance(parsed, list):
                return [str(x).strip() for x in parsed if str(x).strip()]
        except Exception:
            pass

    # Handle python-style list string: "['Admin','X']"
    if s.startswith("[") and s.endswith("]"):
        s = s[1:-1]  # remove brackets
        s = s.replace('"', "").replace("'", "")
        parts = [p.strip() for p in s.split(",") if p.strip()]
        return parts

    # Handle comma separated: "Admin, X"
    if "," in s:
        return [p.strip() for p in s.split(",") if p.strip()]

    # Single group string
    return [s]


def _is_admin(event) -> bool:
    claims = _get_claims(event)
    groups_val = claims.get("cognito:groups")
    groups = _groups_to_list(groups_val)

    # ✅ your group name is exactly "Admin"
    return "Admin" in groups


def _scan_all(table):
    items = []
    kwargs = {}
    while True:
        resp = table.scan(**kwargs)
        items.extend(resp.get("Items", []))
        lek = resp.get("LastEvaluatedKey")
        if not lek:
            break
        kwargs["ExclusiveStartKey"] = lek
    return items


def lambda_handler(event, context):
    # Preflight
    if (event.get("httpMethod") == "OPTIONS") or (
        (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
    ):
        return _resp(200, {"message": "OK"})

    # ✅ Admin guard
    if not _is_admin(event):
        # helpful debug (safe): show if claim exists
        claims = _get_claims(event)
        return _resp(
            403,
            {
                "message": "Forbidden: admin only",
                "debug": {
                    "hasGroupsClaim": "cognito:groups" in claims,
                    "groupsRaw": claims.get("cognito:groups"),
                },
            },
        )

    body = event.get("body") or "{}"
    if isinstance(body, str):
        try:
            body = json.loads(body)
        except Exception:
            body = {}

    table_choice = (body.get("table") or "ALL").strip()
    dry_run = bool(body.get("dryRun", False))

    name_map = {
        "HelpRequests": HELP_REQUESTS_TABLE,
        "HelpOffers": OFFERS_TABLE,
        "NotificationSettings": NOTIF_TABLE,
    }

    targets = list(name_map.keys()) if table_choice.upper() == "ALL" else [table_choice]
    results = {}

    for logical in targets:
        if logical not in name_map:
            results[logical] = {"status": "ERROR", "error": "Unknown table name"}
            continue

        tname = name_map[logical]
        table = ddb.Table(tname)

        try:
            items = _scan_all(table)
            results[logical] = {
                "status": "OK",
                "itemsFound": len(items),
                "deleted": 0,
                "dryRun": dry_run,
                "tableName": tname,
            }

            if dry_run:
                continue

            with table.batch_writer() as batch:
                for it in items:
                    if logical == "HelpRequests":
                        batch.delete_item(Key={"request_id": it["request_id"]})
                    elif logical == "HelpOffers":
                        batch.delete_item(Key={"request_id": it["request_id"], "offer_id": it["offer_id"]})
                    elif logical == "NotificationSettings":
                        batch.delete_item(Key={"user_id": it["user_id"]})

            results[logical]["deleted"] = len(items)

        except Exception as e:
            results[logical] = {"status": "ERROR", "error": str(e)}

    return _resp(200, {"message": "Reset finished", "results": results})