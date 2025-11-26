import os
from typing import Any, Dict, List, Optional
import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key
from ..models.help_request import HelpRequest


class DynamoDbService:
    def __init__(self):
        table_name = os.environ.get("HELP_REQUESTS_TABLE_NAME", "HelpRequests")
        self._table_name = table_name
        self._dynamodb = boto3.resource("dynamodb")
        self._table = self._dynamodb.Table(self._table_name)

    def save_help_request(self, help_request: HelpRequest) -> Dict[str, Any]:
        """
        Save a HelpRequest into DynamoDB.
        Returns the saved item (or raises an error).
        """
        item = help_request.to_item()
        try:
            self._table.put_item(Item=item)
            return item
        except ClientError as e:
            raise RuntimeError(f"Failed to save help request: {e}") from e

    def get_help_request(self, request_id: str) -> Optional[Dict[str, Any]]:
        """
        Fetch a single help request by its primary key (request_id).
        """
        try:
            response = self._table.get_item(Key={"request_id": request_id})
            return response.get("Item")
        except ClientError as e:
            raise RuntimeError(f"Failed to get help request: {e}") from e

    def list_all_help_requests(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Scan the table and return up to 'limit' help requests.
        Used for the Volunteer feed.
        """
        try:
            response = self._table.scan(Limit=limit)
            items = response.get("Items", [])

            # If there is more data, we ignore it for now (Stage 2)
            return items
        except ClientError as e:
            raise RuntimeError(f"Failed to scan help requests: {e}") from e

    def list_help_requests_by_help_seeker(
        self, help_seeker_id: str, limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        Query the GSI 'help_seeker_id-index' to list requests for a specific Help Seeker.
        """
        try:
            response = self._table.query(
                IndexName="help_seeker_id-index",
                KeyConditionExpression=Key("help_seeker_id").eq(help_seeker_id),
                Limit=limit,
            )
            return response.get("Items", [])
        except ClientError as e:
            raise RuntimeError(
                f"Failed to query help requests for help_seeker_id={help_seeker_id}: {e}"
            ) from e