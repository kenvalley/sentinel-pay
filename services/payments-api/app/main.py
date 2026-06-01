"""SentinelPay Payments API — main entrypoint."""
import os
from flask import Flask, jsonify
from app.routes.auth import auth_bp
from app.routes.accounts import accounts_bp
from app.routes.transactions import transactions_bp
from app.routes.wallets import wallets_bp
from app.routes.webhooks import webhooks_bp
from app.routes.admin import admin_bp

# ADDED!
# from flask_limiter import Limiter
# from flask_limiter.util import get_remote_address
from app.limiter import limiter

from app.routes.health import health_bp

# limiter = Limiter(
#     key_func=get_remote_address,
#     storage_uri=os.environ.get("REDIS_URL", "redis://redis:6379/0"),
#     default_limits=[]
# )


# FIXED: Added error handler for uncaught exceptions to prevent verbose stack traces from being exposed in responses.
def create_app():
    app = Flask(__name__)
    app.config["JWT_SECRET"] = os.environ.get("JWT_SECRET", "sentinelpay-dev-secret")
    app.config["ENVIRONMENT"] = os.environ.get("ENVIRONMENT", "development")

    limiter.init_app(app)

    app.register_blueprint(auth_bp, url_prefix="/v1/auth")
    app.register_blueprint(accounts_bp, url_prefix="/v1/accounts")
    app.register_blueprint(transactions_bp, url_prefix="/v1/transactions")
    app.register_blueprint(wallets_bp, url_prefix="/v1/wallets")
    app.register_blueprint(webhooks_bp, url_prefix="/v1/webhooks")
    app.register_blueprint(admin_bp, url_prefix="/v1/admin")
    app.register_blueprint(health_bp)


    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "service": "payments-api"})

    

    # BEFORE [VULNERABLE!]
    # @app.errorhandler(Exception)
    # def handle_exception(e):
    #     # V-APP-09: Verbose error response leaks stack details
    #     import traceback
    #     return jsonify({
    #         "error": str(e),
    #         "type": type(e).__name__,
    #         "trace": traceback.format_exc()
    #     }), 500
    
    # After [FIXED!]
    @app.errorhandler(Exception)
    def handle_exception(e):
        import uuid
        import logging
        import traceback
        error_id = str(uuid.uuid4())[:8].upper()
        logging.getLogger("sentinelpay.errors").error(
            "unhandled_exception",
            extra={
                "error_id":   error_id,
                "error_type": type(e).__name__,
                "trace":      traceback.format_exc(),
            }
        )
        # Client gets only the error ID — no schema, no stack trace
        return jsonify({
            "error":    "An unexpected error occurred.",
            "error_id": error_id
        }), 500


    return app


# if __name__ == "__main__":
#     app = create_app()
#     app.run(host="0.0.0.0", port=8001, debug=True)

# FIXED: Added environment-based debug mode and standardized error handling for better security and operational visibility.
if __name__ == "__main__":
    app = create_app()
    debug = os.environ.get("ENVIRONMENT", "production") != "production"
    app.run(host="0.0.0.0", port=8001, debug=debug)