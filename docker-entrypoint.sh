#!/usr/bin/env bash
# docker-entrypoint.sh — minimal first-boot wrapper for open-webui on Railway.
#
# Responsibilities (kept intentionally tiny):
#   1. Widen ${DATA_DIR} write perms (chmod 777). Railway can re-mount
#      the volume with restrictive attrs on redeploy; this tolerates that.
#   2. Generate WEBUI_SECRET_KEY only when absent. Generated secret persists
#      across restarts because Railway keeps it as a generated service var
#      — but if a user sets/rotates it, we respect their value.
#   3. exec "$@" so the upstream start.sh runs as PID 1 (so signals like
#      SIGTERM from Railway propagate to uvicorn for clean shutdown).
#
# Bash-reserved vars (UID, EUID, USER, HOME, GROUPS, BASH*) are deliberately
# avoided; we never inspect process privilege state, we just chmod.

set -euo pipefail

DATA_DIR="${DATA_DIR:-/data}"

echo "[entrypoint] DATA_DIR=${DATA_DIR}"

mkdir -p "${DATA_DIR}"
# chmod 777 ${DATA_DIR} fixes Railway's root:root 755 bind mount; removing it reintroduces sqlite EACCES.
if ! chmod 777 "${DATA_DIR}" 2>/dev/null; then
  echo "[entrypoint] WARN: chmod 777 ${DATA_DIR} failed (read-only remount?). Continuing." >&2
fi

# chmod 666 widens this DB file's rw perms; sibling -wal/-shm files are created inside the already-chmod-777 dir above.
if [ -f "${DATA_DIR}/webui.db" ]; then
  chmod 666 "${DATA_DIR}/webui.db" 2>/dev/null || true
fi

# WEBUI_SECRET_KEY — only fill if upstream didn't already autogen.
# Upstream's start.sh runs `openssl rand -hex 32` itself when this var is empty,
# so we don't need to seed it here. Leaving unset is correct.
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-}"

echo "[entrypoint] open-webui boot starting: ${DATA_DIR} ready, exec'ing $*"
exec "$@"
