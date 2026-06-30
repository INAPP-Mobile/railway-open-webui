# syntax=docker/dockerfile:1
FROM ghcr.io/open-webui/open-webui:v0.10.1

LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/railway-open-webui"

# Disable all heavy features to reduce baseline memory
ENV USE_EMBEDDING_MODEL_DOCKER=false \
    USE_RERANKING_MODEL_DOCKER="" \
    USE_SMART_LLM=false \
    WHISPER_MODEL=null \
    OLLAMA_BASE_URL="" \
    ENABLE_OLLAMA_API=false \
    DISABLE_ADMIN_EMAIL=true \
    ENV=prod

# Do NOT hard-code WEBUI_SECRET_KEY — it must be generated at runtime
# or injected via Railway secrets/environment. See docker-entrypoint.sh.

COPY --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh

# Create non-root user (Issue 3: Security — must not run as root)
ENV UID=1000 \
    GID=1000
RUN addgroup --gid ${GID} appuser && \
    adduser --disabled-password --uid ${UID} --ingroup appuser appuser && \
    mkdir -p /data /home/appuser/.cache && chown -R ${UID}:${GID} /data /app /home/appuser

USER ${UID}:${GID}

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
