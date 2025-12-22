import json
import os
import math
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
table = dynamodb.Table(TABLE_NAME)

DEFAULT_RADIUS_KM = float(os.environ.get("DEFAULT_RADIUS_KM", "10"))
MAX_RADIUS_KM = float(os.environ.get("MAX_RADIUS_KM", "50"))  # safety


def _convert_decimals(obj):
    if isinstance(obj, list):
        return [_convert_decimals(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj


def _build_response(status_code: int, body):
    if not isinstance(body, str):
        body = json.dumps(body)
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        "body": body,
    }


def _to_float(x):
    try:
        if x is None:
            return None
        if isinstance(x, Decimal):
            return float(x)
        return float(x)
    except Exception:
        return None


def _haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def lambda_handler(event, context):
    try:
        # CORS preflight
        if (event.get("httpMethod") == "OPTIONS") or (
            (event.get("requestContext") or {}).get("http", {}).get("method") == "OPTIONS"
        ):
            return _build_response(200, {"message": "OK"})

        qs = event.get("queryStringParameters") or {}
        lat = _to_float(qs.get("lat"))
        lng = _to_float(qs.get("lng"))
        radius = _to_float(qs.get("radiusKm")) or DEFAULT_RADIUS_KM

        if lat is None or lng is None:
            return _build_response(400, {"message": "Missing required query params: lat, lng"})

        # validate radius
        if radius <= 0:
            return _build_response(400, {"message": "radiusKm must be > 0"})
        if radius > MAX_RADIUS_KM:
            radius = MAX_RADIUS_KM

        # MVP: scan all requests (then filter)
        try:
            resp = table.scan(Limit=500)
            items = resp.get("Items", [])
            while "LastEvaluatedKey" in resp:
                resp = table.scan(ExclusiveStartKey=resp["LastEvaluatedKey"], Limit=500)
                items.extend(resp.get("Items", []))
        except ClientError as e:
            return _build_response(500, {"message": "Failed to scan HelpRequests", "error": str(e)})

        results = []
        for it in items:
            status = (it.get("status") or "").upper().strip()
            if status not in ["OPEN", "IN_PROGRESS"]:
                continue

            it_lat = _to_float(it.get("latitude"))
            it_lng = _to_float(it.get("longitude"))
            if it_lat is None or it_lng is None:
                continue

            d = _haversine_km(lat, lng, it_lat, it_lng)
            if d <= radius:
                it_clean = _convert_decimals(dict(it))
                it_clean["distanceKm"] = round(d, 2)
                results.append(it_clean)

        results.sort(key=lambda x: x.get("distanceKm", 999999))

        return _build_response(200, {"items": results, "count": len(results)})

    except Exception as e:
        return _build_response(500, {"message": "Internal server error", "error": str(e)})