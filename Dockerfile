# syntax=docker/dockerfile:1
FROM ghcr.io/open-webui/open-webui:v0.10.1-slim

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

# ── 3. Non-root user ──
COPY --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh

ENV UID=1000 \
    GID=1000
RUN addgroup --gid ${GID} appuser && \
    adduser --disabled-password --uid ${UID} --ingroup appuser appuser && \
    mkdir -p /data /home/appuser/.cache && chown -R ${UID}:${GID} /data /app

USER ${UID}:${GID}

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://127.0.0.1:${PORT:-8080}/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
