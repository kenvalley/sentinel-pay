"""SentinelPay KYC API — identity verification service."""
import os
from flask import Flask, jsonify

from app.routes.verify import verify_bp
from app.routes.documents import documents_bp

from app.routes.health import health_bp


def create_app():
    app = Flask(__name__)
    app.config["JWT_SECRET"] = os.environ.get("JWT_SECRET", "sentinelpay-dev-secret")

    app.register_blueprint(verify_bp, url_prefix="/v1/verify")
    app.register_blueprint(documents_bp, url_prefix="/v1/documents")
    app.register_blueprint(health_bp)


    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "service": "kyc-api"})

    # ADDED! Added error handler for uncaught exceptions to prevent verbose stack traces from being exposed in responses.
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
        return jsonify({
            "error":    "An unexpected error occurred.",
            "error_id": error_id
        }), 500

    return app


# if __name__ == "__main__":
#     app = create_app()
#     app.run(host="0.0.0.0", port=8002, debug=True)


# FIXED: Added environment-based debug mode and standardized error handling for better security and operational visibility.
if __name__ == "__main__":
    app = create_app()
    debug = os.environ.get("ENVIRONMENT", "production") != "production"
    app.run(host="0.0.0.0", port=8002, debug=debug)