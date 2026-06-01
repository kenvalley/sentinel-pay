# limiter.py
# Flask-Limiter instance — defined here to avoid circular imports.
# main.py initialises it with init_app(); routes import it from here.

import os
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=os.environ.get("REDIS_URL", "redis://redis:6379/0"),
    default_limits=[]
)
