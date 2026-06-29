#!/bin/bash
set -euo pipefail

# Use SQLite backend by default (file-based), or PostgreSQL via env vars
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi

# Ensure /data directory exists and is writable
mkdir -p /data
chmod 700 /data
chown $(id -u):$(id -g) /data

exec /app/backend/start.sh "$@"
