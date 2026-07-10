#!/bin/bash
# Merge stderr into stdout so Railway's log stream captures [boot] markers.
exec 2>&1
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
UID_VAL="${UID:-1000}"
GID_VAL="${GID:-1000}"
PORT_VAL="${PORT:-8080}"

echo "[boot] container pid=$$ user=$(id 2>&1 || echo unknown)" >&2

# ── 1. /data volume perms (Railway mounts as root:root) ────────────────────
chown -R "${UID_VAL}:${GID_VAL}" /data 2>/dev/null \
    || echo "[boot] chown /data returned non-zero (continuing)" >&2
DATA_PERMS=$(stat -c '%a %U:%G' /data 2>/dev/null || echo "stat-fail")
echo "[boot] /data perms=${DATA_PERMS}" >&2

# ── 2. Database URL fallback ──────────────────────────────────────────────
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="sqlite:////data/open_webui.db"
fi
echo "[boot] DATABASE_URL=${DATABASE_URL}" >&2

# Derive a path to pre-touch so SQLAlchemy open() doesn't hit EACCES on
# first run. Upstream open-webui env.py also computes DATA_DIR-based paths
# internally; this match handles both flavours.
case "${DATABASE_URL}" in
    sqlite:////*) DB_FILE="${DATABASE_URL#sqlite:////}" ;;
    sqlite:///*)  DB_FILE="/app/backend/${DATABASE_URL#sqlite:///}" ;;
    *)            DB_FILE="/data/open_webui.db" ;;
esac

mkdir -p "$(dirname "${DB_FILE}")" 2>/dev/null || true
if [ ! -f "${DB_FILE}" ]; then
    touch "${DB_FILE}" 2>/dev/null \
        || echo "[boot] touch ${DB_FILE} failed (EACCES or fs quirk; see perms above)" >&2
    chown "${UID_VAL}:${GID_VAL}" "${DB_FILE}" 2>/dev/null || true
fi
DB_PERMS=$(stat -c '%a %U:%G' "${DB_FILE}" 2>/dev/null || echo "stat-fail")
echo "[boot] DB_FILE=${DB_FILE} exists=$(test -f "${DB_FILE}" && echo Y || echo N) perms=${DB_PERMS}" >&2

# ── 3. WEBUI_SECRET_KEY fallback ──────────────────────────────────────────
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
    export WEBUI_SECRET_KEY="$(head -c 32 /dev/urandom | base64)"
    echo "[boot] Generated runtime WEBUI_SECRET_KEY (no default shipped)" >&2
fi

# ── 4. Disable upstream startup hooks that hang/explode on first boot ──────
# (Per 2026-06-30 reference: slim image tries to download embedding model
# files at startup despite env disables. ENTRYPOINT guards prevent the hang.)
export DISABLE_TOOL_INSTALLER=true
export ENABLE_LSP=false
export DISABLE_COMMUNITY_SHARING=true

# ── 5. Drop privileges to appuser and exec uvicorn ─────────────────────────
# `setpriv --reuid/--regid/--init-groups` runs the program as appuser while
# inheriting the parent's env (PORT, DATABASE_URL, WEBUI_SECRET_KEY all carry
# through). No nested-quoting foot-gun vs su -c.
cd /app/backend
echo "[boot] exec uvicorn on port ${PORT_VAL}" >&2
exec setpriv --reuid="${UID_VAL}" --regid="${GID_VAL}" --init-groups \
    python -m uvicorn open_webui.main:app \
        --host 0.0.0.0 \
        --port "${PORT_VAL}"
