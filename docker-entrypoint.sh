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

# Critical: disable ALL upstream startup hooks that cause hangs/excess memory.
export DISABLE_TOOL_INSTALLER=true
export ENABLE_LSP=false
export DISABLE_COMMUNITY_SHARING=true
export ENABLE_SIGNUP=false

cd /app
exec python -m open_webui.main:app \
    --host 0.0.0.0 \
    --port 8080
