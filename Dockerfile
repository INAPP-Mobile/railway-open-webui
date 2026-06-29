# syntax=docker/dockerfile:1
FROM ghcr.io/open-webui/open-webui:v0.6.29

LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/railway-open-webui"

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
