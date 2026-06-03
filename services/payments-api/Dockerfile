
#FIXED - Updated the Dockerfile to use a non-root user for better security. 
# Also switched to a slim Python image to reduce the attack surface and image size. 
# Added explicit ownership of files to the non-root user.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && useradd -m -u 1001 appuser

COPY --chown=appuser:appuser . .

USER appuser

EXPOSE 8001

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8001", "app.main:create_app()"]





# Original Dockerfile (for reference):

# FROM python:3.11

# WORKDIR /app

# COPY requirements.txt .
# RUN pip install -r requirements.txt

# COPY . .

# EXPOSE 8001

# CMD ["python", "-m", "app.main"]



