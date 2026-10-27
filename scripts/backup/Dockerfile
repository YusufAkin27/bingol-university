# Yedek servisi: pg_dump/pg_restore + age + rclone + zamanlayici. postgres:16-alpine tabanli oldugundan
# verify-restore.sh gecici bir PostgreSQL sunucusunu (initdb) ayni imajda baslatabilir.
FROM postgres:16-alpine
ARG SUPERCRONIC_VERSION=v0.2.33
RUN apk add --no-cache age rclone zstd tar curl bash tzdata su-exec ca-certificates busybox-extras \
    && ARCH="$(uname -m)"; case "$ARCH" in x86_64) A=amd64;; aarch64) A=arm64;; *) A=amd64;; esac \
    && curl -fsSL -o /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${A}" \
    && chmod +x /usr/local/bin/supercronic
COPY lib.sh backup.sh restore.sh verify-restore.sh entrypoint.sh /opt/backup/
RUN chmod +x /opt/backup/*.sh && mkdir -p /var/backups /config/rclone
ENV BACKUP_DIR=/var/backups UPLOADS_DIR=/data/uploads RCLONE_CONFIG=/config/rclone/rclone.conf
EXPOSE 9199
ENTRYPOINT ["/opt/backup/entrypoint.sh"]
