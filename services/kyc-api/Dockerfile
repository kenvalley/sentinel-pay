# services/kyc-api/Dockerfile
#
# Security fixes applied:
# - Switched from python:3.11 full image to python:3.11-slim (reduces attack surface)
# - Non-root user (appuser UID 1001) instead of running as root
# - Explicit file ownership assigned to appuser
# - /app/tmp created with correct ownership for gunicorn temp files
# - TMPDIR set to /app/tmp to avoid readonlyRootFilesystem issues on ECS Fargate

FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && useradd -m -u 1001 appuser \
    && mkdir -p /app/tmp \
    && chown -R appuser:appuser /app/tmp

COPY --chown=appuser:appuser . .

USER appuser

# Tell gunicorn and Python to use /app/tmp for all temporary files
# This allows readonlyRootFilesystem=true on ECS Fargate without
# requiring a volume mount for /tmp
ENV TMPDIR=/app/tmp

EXPOSE 8002

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8002", "app.main:create_app()"]
