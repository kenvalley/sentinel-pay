import json
import logging
import time
from flask import request

audit_logger = logging.getLogger("sentinelpay.audit")
audit_logger.setLevel(logging.INFO)


def emit(event_type: str, outcome: str, **kwargs):
    """
    Emit a structured audit log entry to stdout (captured by CloudWatch).
    Every sensitive operation must call this before returning.
    """
    entry = {
        "event_type": event_type,
        "outcome":    outcome,
        "actor_id":   getattr(request, "current_user_id", None),
        "source_ip":  request.remote_addr,
        "timestamp":  int(time.time()),
        **kwargs
    }
    audit_logger.info(json.dumps(entry))