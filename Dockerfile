FROM ghcr.io/open-webui/open-webui:v0.6.18
# Run as root: chmod the Railway volume mount target so appuser(uid 1000)
# can write to /app/backend/data for sqlite-wal/-shm (Railway mounts root:root 755).
USER root
RUN mkdir -p /app/backend/data /home/appuser/.cache
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["bash", "/app/backend/start.sh"]
