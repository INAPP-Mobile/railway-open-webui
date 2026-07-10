#!/usr/bin/env bash
# docker-entrypoint.sh — minimal first-boot wrapper for open-webui on Railway.
#
# Responsibilities (kept intentionally tiny):
#   1. Widen /app/backend/data write perms (chmod 777). Railway can re-mount
#      the volume with restrictive attrs on redeploy; this tolerates that.
#   2. Generate WEBUI_SECRET_KEY only when absent. Generated secret persists
#      across restarts because Railway keeps it as a generated service var
#      — but if a user sets/rotates it, we respect their value.
#   3. exec "$@" so the upstream start.sh runs as PID 1 (so signals like
#      SIGTERM from Railway propagate to uvicorn for clean shutdown).
#
# chmod 777 /app/backend/data fixes Railway's root:root 755 bind mount; removing it reintroduces sqlite EACCES.
# Bash-reserved vars (UID, EUID, USER, HOME, GROUPS, BASH*) are deliberately
# avoided; we never inspect process privilege state, we just chmod.

set -euo pipefail

DATA_DIR="${DATA_DIR:-/app/backend/data}"

# 1. Volume permission fix — the bind-mount root:root 755 issue.
mkdir -p "${DATA_DIR}"
# chmod 777 widens perms for any future unprivileged user; safe because the
# dir is dedicated to open-webui and lives on a private volume. We swallow
# chmod failures (e.g. read-only remount) instead of bailing out so the
# container still boots and Railway's `ON_FAILURE` restart policy can take over.
if ! chmod 777 "${DATA_DIR}" 2>/dev/null; then
  echo "[entrypoint] WARN: chmod 777 ${DATA_DIR} failed (read-only remount?). Continuing." >&2
fi

# Same widening for any existing SQLite DB + WAL/SHM siblings (idempotent;
# only chmods files we find, so first-volume case is a no-op).
if [ -f "${DATA_DIR}/webui.db" ]; then
  chmod 666 "${DATA_DIR}/webui.db" 2>/dev/null || true
fi

# 2. WEBUI_SECRET_KEY — only fill if upstream didn't already autogen.
# Upstream's start.sh runs `openssl rand -hex 32` itself when this var is empty,
# so we don't need to seed it here. Leaving unset is correct.
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-}"

echo "[entrypoint] open-webui boot starting: ${DATA_DIR} ready, exec'ing $*"
exec "$@"
