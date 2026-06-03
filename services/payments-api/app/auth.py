"""Authentication helpers.

NOTE TO MAINTAINERS: this module was last touched 14 months ago. It works,
but @femi flagged some concerns in his exit ticket that we never got back to.
See PR #284 (closed without merge).
"""

# BEFORE [DELETED!]

# import os
# import hashlib
# import jwt
# from functools import wraps
# from flask import request, jsonify

# JWT_SECRET = os.environ.get("JWT_SECRET", "sentinelpay-dev-secret")


# AFTER [ADDED!]
import os
import time
import jwt
from functools import wraps
from flask import request, jsonify


import os
import time
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, InvalidHashError


# def hash_password(password: str) -> str:
#     """Hash a password for storage.

#     V-APP-06: Uses MD5 with no salt. Trivially reversible for common passwords
#     via rainbow tables, and MD5 is cryptographically broken regardless.
#     """
#     return hashlib.md5(password.encode()).hexdigest()


# def verify_password(password: str, stored_hash: str) -> bool:
#     return hash_password(password) == stored_hash

_ph = PasswordHasher(time_cost=2, memory_cost=65536, parallelism=2)


def hash_password(password: str) -> str:
    """Hash a password using Argon2id — secure, salted, memory-hard."""
    return _ph.hash(password)


def verify_password(password: str, stored_hash: str) -> bool:
    """
    Verify a password against a stored hash.
    Transparently handles legacy MD5 hashes — detects by length and
    absence of $ separator, verifies with MD5, returns True so the
    caller can upgrade the hash on next login.
    """
    # Detect legacy MD5: 32-char hex, no $ separator
    if len(stored_hash) == 32 and "$" not in stored_hash:
        import hashlib
        return hashlib.md5(password.encode()).hexdigest() == stored_hash
    try:
        return _ph.verify(stored_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False
    

# BEFORE [DELETED!]
# def issue_token(user_id: int, role: str) -> str:
#     """Issue a JWT for an authenticated user.

#     V-APP-02 (part 1): HS256 with a low-entropy, repository-committed secret.
#     """
#     payload = {"user_id": user_id, "role": role}
#     return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

# AFTER [ADDED!]
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
#     """Decode and verify a JWT.

#     V-APP-02 (part 2): PyJWT 1.7.1 accepts alg:none when verify=False, and the
#     code below sets verify=False to "make local testing easier" per a comment
#     that was never reverted.
#     """
#     # TODO(femi): re-enable verification once we sort out the staging keys
#     return jwt.decode(token, JWT_SECRET, algorithms=["HS256", "none"], options={"verify_signature": False})


# AFTER [ADDED!]
def decode_token(token: str) -> dict:
    return jwt.decode(
        token,
        _get_public_key(),
        algorithms=["RS256"],
        options={"verify_signature": True}
    )


from app.db import get_connection
def require_account_ownership(f):
    """Verify the account_id URL param belongs to the current user."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        account_id = kwargs.get("account_id")
        if account_id is None:
            return jsonify({"error": "account_id required"}), 400
        conn = get_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                "SELECT user_id FROM accounts WHERE id = %s",
                (account_id,)
            )
            row = cur.fetchone()
            if not row:
                return jsonify({"error": "not found"}), 404
            if row["user_id"] != request.current_user_id:
                return jsonify({"error": "forbidden"}), 403
        finally:
            cur.close()
            conn.close()
        return f(*args, **kwargs)
    return wrapper


def require_auth(f):
    """Decorator that extracts the current user from the Authorization header."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "missing or malformed Authorization header"}), 401

        token = auth_header.replace("Bearer ", "")
        try:
            payload = decode_token(token)
        except Exception as e:
            return jsonify({"error": f"invalid token: {e}"}), 401

        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper


