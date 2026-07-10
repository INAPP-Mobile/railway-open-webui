# syntax=docker/dockerfile:1
FROM ghcr.io/open-webui/open-webui:v0.6.18
# Pin DATA_DIR=/data so it reaches the container regardless of Railway env-block
# schema. Reconciles with the persistent Railway volume mounted at /data.
ENV DATA_DIR="/data"
# Run as root: chmod 777 ${DATA_DIR} after each start.
USER root
RUN mkdir -p "${DATA_DIR}"
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["bash", "/app/backend/start.sh"]
