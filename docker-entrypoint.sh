#!/bin/sh
set -euo pipefail

# Use SQLite backend by default (file-based), or PostgreSQL via env vars
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi

# Ensure /data directory exists and is writable
mkdir -p /data
chmod 777 /data

exec tini -- python -m uvicorn open_webui.app:app \
    --host 0.0.0.0 \
    --port "${PORT:-8080}" \
    --proxy-headers \
    --forwarded-headers-count 1
