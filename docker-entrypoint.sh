#!/bin/bash
set -euo pipefail

# ── 1. Fix /data ownership at runtime ─────────────────────────────────────
# Railway mounts the /data volume with root:root at deploy time, but Open WebUI
# runs as appuser (UID 1000). The build-time `chown /data` further up in the
# Dockerfile is silently overwritten by the volume mount, so we have to chown
# here on every boot — before uvicorn tries to open /data/open_webui.db.
chown -R "${UID:-1000}:${GID:-1000}" /data

echo "[boot] post-chown: id=$(id); /data perms=$(stat -c '%a %U:%G' /data 2>&1)" >&2

# ── 2. Database URL ───────────────────────────────────────────────────────
if [ -z "${DATABASE_URL:-}" ]; then
    # 4-slash form = absolute Linux path. SQLite will create the file on first open.
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi

echo "[boot] DATABASE_URL=${DATABASE_URL}" >&2
echo "[boot] /data listing:" >&2
ls -la /data 2>&1 | head -20 >&2 || echo "[boot] ls failed" >&2

# ── 3. WEBUI_SECRET_KEY (only if user didn't set it) ──────────────────────
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
    export WEBUI_SECRET_KEY=$(head -c 32 /dev/urandom | base64)
    echo "INFO: Generated runtime WEBUI_SECRET_KEY (no default shipped)" >&2
fi

# ── 4. Disable upstream startup hooks that hang/explode on first boot ──────
# ENABLE_SIGNUP stays user-controlled via the deploy form / Variables tab —
# it's a runtime flag, NOT a startup hook.
export DISABLE_TOOL_INSTALLER=true
export ENABLE_LSP=false
export DISABLE_COMMUNITY_SHARING=true

# ── 5. Drop privileges to appuser and exec uvicorn ─────────────────────────
# `setpriv --reuid/--regid/--init-groups` runs the program as appuser while
# inheriting the parent's env (RAILWAY_PUBLIC_DOMAIN, PORT, DATABASE_URL,
# WEBUI_SECRET_KEY all carry through). No sub-shell quoting foot-gun vs su -c.
cd /app/backend
exec setpriv --reuid="${UID:-1000}" --regid="${GID:-1000}" --init-groups \
    python -m uvicorn open_webui.main:app \
    --host 0.0.0.0 \
    --port "${PORT:-8080}"
