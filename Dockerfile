# syntax=docker/dockerfile:1
# Open WebUI Railway Template
# Thin wrapper around the upstream ghcr.io image: chmod the volume mount
# target + exec upstream start.sh so alembic + lifespan run as upstream
# designed them to.

FROM ghcr.io/open-webui/open-webui:v0.6.18

USER root
RUN mkdir -p /app/backend/data /home/appuser/.cache
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["bash", "/app/backend/start.sh"]
