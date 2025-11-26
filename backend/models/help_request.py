from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional
import uuid


@dataclass
class HelpRequest:
    request_id: str
    help_seeker_id: str
    title: str
    description: str
    category: str
    urgency: str
    location: str
    image_key: Optional[str]
    status: str
    created_at: str  # ISO 8601 string

    @staticmethod
    def create_new(
        help_seeker_id: str,
        title: str,
        description: str,
        category: str,
        urgency: str,
        location: str,
        image_key: Optional[str] = None,
    ) -> "HelpRequest":
        """
        Factory method to create a new HelpRequest with generated ID, status and timestamp.
        """
        now = datetime.utcnow().isoformat() + "Z"
        return HelpRequest(
            request_id=str(uuid.uuid4()),
            help_seeker_id=help_seeker_id,
            title=title,
            description=description,
            category=category,
            urgency=urgency,
            location=location,
            image_key=image_key,
            status="Open",
            created_at=now,
        )

    def to_item(self) -> dict:
        """
        Convert to a DynamoDB item dict.
        """
        return asdict(self)