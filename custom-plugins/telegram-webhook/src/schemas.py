from pydantic import BaseModel
from typing import List, Dict, Optional


# Convert JSON from webhook to Python Object
"""
The Alertmanager will send HTTP Post requests in the following JSON format
Link here:
https://prometheus.io/docs/alerting/latest/configuration/#webhook_config

These code convert JSON format into Python object for sending to telegram via python
"""
class Alert(BaseModel):
    status: str
    labels: Dict[str, str]
    annotations: Dict[str, str]
    startsAt: str
    endsAt: Optional[str] = None

class AlertmanagerPayload(BaseModel):
    receiver: str
    status: str
    alerts: List[Alert]
    groupLabels: Dict[str, str]
    commonLabels: Dict[str, str]
    externalURL: str