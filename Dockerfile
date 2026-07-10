# syntax=docker/dockerfile:1
FROM ghcr.io/open-webui/open-webui:v0.6.18
# Run as root: chmod 777 /app/backend/data after each start (12+ deploys failed without; see commit history).
USER root
RUN mkdir -p /app/backend/data /home/appuser/.cache
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["bash", "/app/backend/start.sh"]
