# syntax=docker/dockerfile:1
# Slim variant skips heavy auto-init (embedding models, Whisper, etc.)
FROM ghcr.io/open-webui/open-webui:v0.6.29-slim

LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/railway-open-webui"

ENV USE_EMBEDDING_MODEL_DOCKER=false
ENV USE_RERANKING_MODEL_DOCKER=""
ENV WHISPER_MODEL=null
ENV WEBUI_SECRET_KEY=open_webui_railway_secret_key
ENV ENV=prod

# Pre-generate secret key so startup doesn't hang waiting for it
RUN mkdir -p /app/backend/.secrets \
    && head -c 32 /dev/urandom | base64 > /app/backend/.secrets/.webui_secret_key \
    && chmod 600 /app/backend/.secrets/.webui_secret_key

COPY --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh

# Create non-root user (Issue 3: Security — must not run as root)
ENV UID=1000
ENV GID=1000
RUN addgroup --gid ${GID} appuser && \
    adduser --disabled-password --uid ${UID} --ingroup appuser appuser && \
    mkdir -p /data /home/appuser/.cache && chown -R ${UID}:${GID} /data /app /home/appuser

USER ${UID}:${GID}

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
