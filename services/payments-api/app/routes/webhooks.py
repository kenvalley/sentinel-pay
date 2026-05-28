"""Webhook registration and callback testing."""
import os
import requests
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.security import validate_callback_url # ADDED!

webhooks_bp = Blueprint("webhooks", __name__)

WEBHOOK_TIMEOUT = int(os.environ.get("WEBHOOK_TIMEOUT", "10"))


@webhooks_bp.route("/", methods=["POST"])
@require_auth
def register_webhook():
    """Register a callback URL for transaction events."""
    data = request.get_json() or {}
    callback_url = data.get("callback_url")
    event_type = data.get("event_type", "transaction.completed")

    if not callback_url:
        return jsonify({"error": "callback_url required"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO webhooks (user_id, callback_url, event_type) VALUES (%s, %s, %s) RETURNING id",
            (request.current_user_id, callback_url, event_type)
        )
        webhook_id = cur.fetchone()["id"]
        conn.commit()
        return jsonify({"id": webhook_id, "callback_url": callback_url}), 201
    finally:
        cur.close()
        conn.close()


# FIXED: Added a test endpoint to validate callback URLs and demonstrate webhook functionality.
@webhooks_bp.route("/test", methods=["POST"])
@require_auth
def test_webhook():
    data = request.get_json() or {}
    url = data.get("url")

    if not url:
        return jsonify({"error": "url required"}), 400

    try:
        url = validate_callback_url(url)
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    try:
        resp = requests.get(
            url,
            timeout=WEBHOOK_TIMEOUT,
            allow_redirects=False   # prevent open redirect
        )
        # Return status only — body stripped to prevent exfiltration
        return jsonify({"status_code": resp.status_code})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
