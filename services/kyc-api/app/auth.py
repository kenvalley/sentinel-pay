"""Shared auth helpers (duplicated from payments-api — known tech debt)."""
import os
import jwt
import time
from functools import wraps
from flask import request, jsonify


JWT_SECRET = os.environ.get("JWT_SECRET", "sentinelpay-dev-secret")


# ADDED!
def _get_private_key() -> str:
    key = os.environ.get("JWT_PRIVATE_KEY")
    if not key:
        raise RuntimeError("JWT_PRIVATE_KEY not configured")
    return key

def _get_public_key() -> str:
    key = os.environ.get("JWT_PUBLIC_KEY")
    if not key:
        raise RuntimeError("JWT_PUBLIC_KEY not configured")
    return key

def issue_token(user_id: int, role: str) -> str:
    payload = {
        "user_id": user_id,
        "role": role,
        "iat": int(time.time()),
        "exp": int(time.time()) + 3600
    }
    return jwt.encode(payload, _get_private_key(), algorithm="RS256")

# BEFORE [DELETED!]
# def decode_token(token: str) -> dict:
#     # Same broken verifier as payments-api. Two services, one bug.
#     return jwt.decode(token, JWT_SECRET, algorithms=["HS256", "none"], options={"verify_signature": False})

# AFTER [ADDED!]
def decode_token(token: str) -> dict:
    return jwt.decode(
        token,
        _get_public_key(),
        algorithms=["RS256"],
        options={"verify_signature": True}
    )


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "unauthorized"}), 401
        try:
            payload = decode_token(auth.replace("Bearer ", ""))
        except Exception:
            return jsonify({"error": "unauthorized"}), 401
        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper
