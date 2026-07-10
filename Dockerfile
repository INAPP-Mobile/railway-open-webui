# syntax=docker/dockerfile:1
FROM ghcr.io/open-webui/open-webui:v0.10.2-slim

LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/railway-open-webui"

# ── 1. Env vars to disable RAG/embedding pipelines ──
ENV EMBEDDING_MODEL="" \
    OVERRIDE_EMBEDDING_MODEL="" \
    RAG_EMBEDDING_MODEL="" \
    EMBEDDING_ENGINE="" \
    USE_EMBEDDING_MODEL_DOCKER=false \
    USE_AUXILIARY_EMBEDDING_MODEL_DOCKER=false \
    RERANKING_MODEL="" \
    OVERRIDE_RERANKING_MODEL="" \
    RERANKING_ENGINE="" \
    USE_RERANKING_MODEL_DOCKER=false \
    ENABLE_OLLAMA_API=false \
    OLLAMA_BASE_URL="" \
    DISABLE_TOOL_INSTALLER=true \
    DISABLE_ADMIN_EMAIL=true \
    ENABLE_SMART_LLM=false

# ── 2. Patch hardcoded model names in upstream config files at build time ──
# The slim image ships Python files with 'sentence-transformers/all-MiniLM-L6-v2' as
# fallback strings inside `or`-chains. No env var can override these — we patch them out.
# Also install curl for HEALTHCHECK (not included in slim image).
COPY docker-patch-config.py /tmp/docker-patch-config.py

RUN python3 /tmp/docker-patch-config.py 2>/dev/null || true && \
    apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# ── 3. Custom boot wrapper ──
# Upstream's CMD is ["bash", "start.sh"] invoked with WORKDIR=/app/backend.
# We MUST NOT clobber /app/backend/start.sh: the slim image's start.sh runs
# alembic migrations, generates .webui_secret_key on first boot, and does
# the FastAPI lifespan init that registers routers. Without those, uvicorn
# binds to :8080 but serves a 404 for every route (verified locally with
# podman run on the unmodified upstream image).
#
# Our wrapper (copied to a NEW path so upstream's start.sh survives) runs
# preflight: chown/chmod /app/backend/data (Railway volume mount target),
# chmod 666 the DB file, generate WEBUI_SECRET_KEY, then exec setpriv
# bash /app/backend/start.sh so upstream's full startup pipeline runs
# under appuser.
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/railway-entrypoint.sh

# Run as root throughout: this matches upstream open-webui's default (User=0:0
# in the upstream image), and Railway-managed volume mounts are typically
# root:root 755 with restricted chmod/chown (the same bind-mount CAP_CHOWN
# restriction we hit locally with /tmp bind mounts).
#
# Earlier we tried dropping privileges via setpriv to a dedicated appuser
# (UID=1000). That hit EACCES on SQLite -wal/-shm writes because the
# container cannot chown/chmod the underlying host volume inode. Stop fighting
# the volume mount and run start.sh directly as root, like upstream does.
#
# mkdir -p /app/backend/data ensures the Railway volume mount attaches to
# an existing directory inode (otherwise Docker creates it AS ROOT with
# stricter 700 mode, which would still be fine since we run as root).
RUN mkdir -p /app/backend/data /home/appuser/.cache

USER root

EXPOSE 8080

# TCP-socket open probe is more reliable than `curl /` during lifespan scan:
# open-webui v0.10.x does a static-asset walk on first request that often
# exceeds --timeout=10s. /dev/tcp probe just confirms uvicorn bound the port.
# Hardcoded 8080 to avoid fragile PORT-expansion edge cases (Dockerfile
# parser mishandling the backslash escape would break the probe silently);
# matches `EXPOSE 8080` and Railway's default PORT=8080.
# start-period=120s gives alembic + secret-key generation time before the
# first probe (chroma init can take 30-60s on first boot).
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD bash -c "exec 3<>/dev/tcp/127.0.0.1/8080" || exit 1

# CRITICAL: override CMD with ENTRYPOINT to defend against Railway's
# platform occasionally running OLD cached deploys. Even if our CMD
# override should work, ENTRYPOINT is more idiomatic when overriding
# the upstream image's CMD-as-PID-1 pattern. With ENTRYPOINT, Docker
# can't append our wrapper as a positional argument to the upstream
# ENTRYPOINT (defense in depth).
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]    
