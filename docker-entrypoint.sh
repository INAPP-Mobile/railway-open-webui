#!/bin/bash
# Merge stderr into stdout so Railway's log stream captures [boot] markers.
exec 2>&1
set -euo pipefail

# BASH/DOCKER-RESERVED-VAR WARNING:
# Reading $UID / $GID / $EUID / $USER / $HOME / $GROUPS / $PPID / $SECONDS
# directly inside this script will silently misbehave: bash auto-injects
# UID/EUID/GROUPS/PPID/SECONDS as read-only virtual vars equal to the
# running shell's effective identity, and Docker injects USER (from the
# USER directive) and HOME (OS default). When the wrapper runs as
# USER root these all resolve to root, breaking any privilege-drop logic.
# Always read from the Dockerfile-set APP_UID / APP_GID env (defined in
# the `ENV APP_UID=1000 APP_GID=1000` line). This cost 8 deploys already.

# CRITICAL: do NOT read from $UID/$GID directly — bash reserves those as
# read-only virtual variables equal to the *effective* user/id of the shell.
# When this script runs as USER root, $UID=0 clobbers whatever Dockerfile
# tried to set. Always read from APP_UID / APP_GID env (defined in Dockerfile).
UID_VAL="${APP_UID:-1000}"
GID_VAL="${APP_GID:-1000}"
PORT_VAL="${PORT:-8080}"

echo "[boot] container pid=$$ user=$(id 2>&1 || echo unknown) APP_UID=${APP_UID:-unset} APP_GID=${APP_GID:-unset}" >&2

# 1. /app/backend/data volume perms.
#    Railway mounts the persistent volume at /app/backend/data (we moved
#    off /data because /tmp-style bind mounts frequently reject chmod
#    777 there; open-webui's internal code needs WRITE on this dir for
#    /uploads and SQLite -wal/-shm sidecar files).
#
#    Build time already chown -R /app to appuser. The volume mount
#    inherits our ownership, so appuser can write directly even if chmod
#    fails. chmod 777 here widens the dir for any process that drops
#    privileges further; safe because /app/backend/data is single-tenant.
if chown -R "${UID_VAL}:${GID_VAL}" /app/backend/data 2>/dev/null; then
    echo "[boot] chown /app/backend/data -> ${UID_VAL}:${GID_VAL} (OK)" >&2
else
    echo "[boot] chown /app/backend/data FAILED (bind-mount rejected CAP_CHOWN; relying on chmod 777 + build-time /app/backend dir)" >&2
fi
if chmod 777 /app/backend/data 2>/dev/null; then
    echo "[boot] chmod 777 /app/backend/data (OK)" >&2
else
    echo "[boot] chmod 777 /app/backend/data FAILED (bind-mount rejected syscall; chmod may need to be done by Railway)" >&2
fi
DATA_PERMS=$(stat -c '%a %U:%G' /app/backend/data 2>/dev/null || echo "stat-fail")
DATA_OWNER=$(stat -c '%U:%G' /app/backend/data 2>/dev/null || echo "owner-fail")
echo "[boot] /app/backend/data perms=${DATA_PERMS} owner=${DATA_OWNER}" >&2

# 2. Database URL fallback (sqlite means alembic creates the file).
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="sqlite:////app/backend/data/webui.db"
fi
echo "[boot] DATABASE_URL=${DATABASE_URL}" >&2

# Derive DB_FILE from DATABASE_URL so the touch + chmod land on the
# same path the app opens. All branches land under /app/backend so we
# avoid the dead /data fallback that previous versions used.
case "${DATABASE_URL}" in
    sqlite:////*) DB_FILE="${DATABASE_URL#sqlite:////}" ;;
    sqlite:///*)  DB_FILE="/app/backend/${DATABASE_URL#sqlite:///}" ;;
    *)            DB_FILE="/app/backend/data/webui.db" ;;
esac

mkdir -p "$(dirname "${DB_FILE}")" 2>/dev/null || true
if [ ! -f "${DB_FILE}" ]; then
    if touch "${DB_FILE}" 2>/dev/null; then
        echo "[boot] touch ${DB_FILE} (OK)" >&2
    else
        echo "[boot] touch ${DB_FILE} FAILED (EACCES or fs quirk; alembic will create)" >&2
    fi
fi
# Always chmod 666 + chown so appuser can read+write the DB file regardless
# of whether we created it (existing files from prior deploys may have
# restrictive modes from a chmod-failing bind mount).
if chmod 666 "${DB_FILE}" 2>/dev/null; then
    echo "[boot] chmod 666 ${DB_FILE} (OK)" >&2
else
    echo "[boot] chmod 666 ${DB_FILE} FAILED (continuing; appuser may have ACL)" >&2
fi
chown "${UID_VAL}:${GID_VAL}" "${DB_FILE}" 2>/dev/null || true
DB_PERMS=$(stat -c '%a %U:%G' "${DB_FILE}" 2>/dev/null || echo "stat-fail")
echo "[boot] DB_FILE=${DB_FILE} exists=$(test -f "${DB_FILE}" && echo Y || echo N) perms=${DB_PERMS}" >&2

# 3. WEBUI_SECRET_KEY fallback (alembic + lifespan both require it).
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
    export WEBUI_SECRET_KEY="$(head -c 32 /dev/urandom | base64)"
    echo "[boot] Generated runtime WEBUI_SECRET_KEY" >&2
fi

# 4. Disable upstream startup hooks that hang/explode on first boot.
export DISABLE_TOOL_INSTALLER=true
export ENABLE_LSP=false
export DISABLE_COMMUNITY_SHARING=true

# 5. DATA_DIR = /app/backend/data (where Railway mounts the persistent vol).
export DATA_DIR="/app/backend/data"
echo "[boot] DATA_DIR=${DATA_DIR}" >&2

# 6. Sanity check + delegate to upstream's startup script.
# We deliberately do NOT exec uvicorn ourselves — upstream's start.sh
# runs alembic upgrade (creates tables in the SQLite first boot),
# generates .webui_secret_key on first boot, and finishes the FastAPI
# lifespan init that registers routers. v0.10.x silently returns 404
# on every route if those startup phases are skipped.
if [ ! -d /app/backend ]; then
    echo "[boot] FATAL: /app/backend missing (image corruption)" >&2
    exit 2
fi
if [ ! -r /app/backend/start.sh ]; then
    echo "[boot] FATAL: /app/backend/start.sh missing/unreadable (image corruption)" >&2
    exit 2
fi
cd /app/backend
echo "[boot] delegating to upstream start.sh (bash pid=$$ -> setpriv --reuid=${UID_VAL} --regid=${GID_VAL} bash /app/backend/start.sh)" >&2

# setpriv drops to appuser while inheriting our patched env (PORT,
# DATABASE_URL, WEBUI_SECRET_KEY, DATA_DIR). The `exec` replaces the
# current bash with setpriv so it stays PID 1's child chain.
exec setpriv --reuid="${UID_VAL}" --regid="${GID_VAL}" --init-groups \
    bash /app/backend/start.sh
