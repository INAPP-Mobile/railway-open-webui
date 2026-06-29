#!/bin/bash
set -euo pipefail

# Use SQLite backend by default (file-based), or PostgreSQL via env vars
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi

# Ensure /data directory exists and is writable
mkdir -p /data
chmod 777 /data

# Change to the backend working directory where open_webui lives
cd /app/backend

exec python -m uvicorn open_webui.main:app \
    --host 0.0.0.0 \
    --port "${PORT:-8080}" \
    --proxy-headers
