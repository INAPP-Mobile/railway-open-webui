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
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi
echo "[boot] DATABASE_URL=${DATABASE_URL}" >&2
echo "[boot] /data listing:" >&2
ls -la /data 2>&1 | head -20 >&2 || echo "[boot] ls failed" >&2

# Derive DB_FILE from DATABASE_URL so the touch lands on the same path the app
# opens. The slim image's open_webui.env honours the env override; if a future
# version ignores DATABASE_URL, the upstream CWD-relative default
# `/app/backend/<path>` is also a valid touch target.
case "${DATABASE_URL:-sqlite:////data/open_webui.db}" in
    sqlite:////*) DB_FILE="${DATABASE_URL#sqlite:////}" ;;
    sqlite:///*)  DB_FILE="/app/backend/${DATABASE_URL#sqlite:///}" ;;
    *)            DB_FILE=/data/open_webui.db ;;
esac

mkdir -p "$(dirname "$DB_FILE")" 2>/dev/null || true
if [ ! -f "$DB_FILE" ]; then
    touch "$DB_FILE" 2>/dev/null \
        || echo "[boot] touch $DB_FILE failed (EACCES or fs quirk; see perms above)" >&2
    chown "${UID:-1000}:${GID:-1000}" "$DB_FILE" 2>/dev/null || true
fi
echo "[boot] DB_FILE=$DB_FILE exists=$(test -f "$DB_FILE" && echo Y || echo N) perms=$(stat -c '%a %U:%G' "$DB_FILE" 2>/dev/null || echo "stat-fail")" >&2

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
