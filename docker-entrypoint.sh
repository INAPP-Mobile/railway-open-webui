#!/bin/bash
set -euo pipefail

# Use SQLite backend by default (file-based), or PostgreSQL via env vars
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi

# Generate WEBUI_SECRET_KEY at runtime if not provided — never ship a default.
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
    export WEBUI_SECRET_KEY="$(head -c 32 /dev/urandom | base64)"
    echo "INFO: Generated runtime WEBUI_SECRET_KEY (no default shipped)" >&2
fi

# Determine start command; fall back to entrypoint logic
if [ -f "/app/backend/start.sh" ]; then
    # start.sh exists in slim variant — run migrations and start
    exec /app/backend/start.sh "$@"
else
    # Bare-bones fallback: use uvicorn directly
    cd /app
    exec python -m uvicorn "open_webui.routes:app" \
        --host 0.0.0.0 --port 8080
fi
