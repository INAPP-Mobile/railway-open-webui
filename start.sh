#!/bin/bash
# Custom start script — bypasses upstream start.sh which hangs in lifespan hooks.
# Skips the external tool installer / migration loop that is not needed on Railway
# since DATABASE_URL is set to SQLite at runtime and tools are pre-built into the image.

set -euo pipefail

cd /app/backend

# Ensure data dir exists
mkdir -p /data

exec python -m uvicorn open_webui.main:app \
    --host 0.0.0.0 \
    --port 8080
