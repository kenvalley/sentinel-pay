"""Authentication routes: registration, login, and OTP."""

# BEFORE [DELETED!]
# from flask import Blueprint, request, jsonify
# from app.db import get_connection
# from app.auth import hash_password, verify_password, issue_token


# AFTER [ADDED!]
from flask import Blueprint, request, jsonify
from pydantic import ValidationError
from app.db import get_connection
from app.auth import hash_password, verify_password, issue_token
from app.schemas import RegisterSchema
from app.limiter import limiter


auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/register", methods=["POST"])
@limiter.limit("10 per hour") # ADDED! Rate limiting to prevent abuse of the registration endpoint.

# FIXED: Added password hashing and input validation. Role is now fixed to "merchant" and not taken from the request body.
def register():
    try:
        payload = RegisterSchema(**(request.get_json() or {}))
    except ValidationError as e:
        return jsonify({"error": e.errors()}), 400

    role = "merchant"  # always — never from request body

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO users (email, password_hash, full_name, role) "
            "VALUES (%s, %s, %s, %s) RETURNING id",
            (payload.email, hash_password(payload.password), payload.full_name, role)
        )
        user_id = cur.fetchone()["id"]
        conn.commit()
        return jsonify({"id": user_id, "email": payload.email, "role": role}), 201
    finally:
        cur.close()
        conn.close()


@auth_bp.route("/login", methods=["POST"])
@limiter.limit("5 per minute; 20 per hour") # ADDED! Rate limiting to mitigate brute-force attacks.
def login():
    """Authenticate a user and issue a JWT.

    V-APP-08: No rate limiting or lockout. Brute force is trivial.
    """
    data = request.get_json() or {}
    email = data.get("email")
    password = data.get("password")

    conn = get_connection()
    cur = conn.cursor()
    try:

        # Vulnerable code - BEFORE [FIXED!]
        # cur.execute("SELECT id, password_hash, role, is_active FROM users WHERE email = %s", (email,))
        # user = cur.fetchone()
        # if not user or not verify_password(password, user["password_hash"]):
        #     return jsonify({"error": "invalid credentials"}), 401
        # if not user["is_active"]:
        #     return jsonify({"error": "account suspended"}), 403

        # token = issue_token(user["id"], user["role"])
        # return jsonify({"token": token, "user_id": user["id"], "role": user["role"]})

        # FIXED: Added password hashing and account status checks. Also implemented a transparent upgrade path for existing MD5 hashes.
        cur.execute("SELECT id, password_hash, role, is_active FROM users WHERE email = %s", (email,))
        user = cur.fetchone()
        
        
        # if not user or not verify_password(password, user["password_hash"]):
        #     return jsonify({"error": "invalid credentials"}), 401

        # FIXED - Added audit logging for both successful and failed login attempts, including reasons for failure.
        if not user or not verify_password(password, user["password_hash"]):
            emit(
                event_type="auth.login.failure",
                outcome="failure",
                reason="invalid_credentials",
            )
            return jsonify({"error": "invalid credentials"}), 401

        if not user["is_active"]:
            return jsonify({"error": "account suspended"}), 403

        # Transparent upgrade: re-hash if still MD5
        if "$" not in user["password_hash"]:
            new_hash = hash_password(password)
            cur.execute(
                "UPDATE users SET password_hash = %s WHERE id = %s",
                (new_hash, user["id"])
            )
            conn.commit()

        # token = issue_token(user["id"], user["role"])
        # return jsonify({"token": token, "user_id": user["id"], "role": user["role"]})

        # FIXED 
        from app.audit import emit
        emit(
            event_type="auth.login.success",
            outcome="success",
            user_id=user["id"],
        )
        token = issue_token(user["id"], user["role"])
        return jsonify({"token": token, "user_id": user["id"], "role": user["role"]})

    finally:
        cur.close()
        conn.close()


# ADDED! A simple OTP request endpoint to demonstrate rate limiting and secure OTP generation. 
# In a real application, this would integrate with an SMS provider and not return the OTP in the response.
@auth_bp.route("/otp", methods=["POST"])
@limiter.limit("3 per minute")
def request_otp():
    import secrets
    data = request.get_json() or {}
    phone = data.get("phone")

    otp = secrets.token_hex(3).upper()  # CSPRNG — not random.randint
    # OTP would be sent via SMS provider here — not logged

    return jsonify({"status": "sent", "phone": phone})
