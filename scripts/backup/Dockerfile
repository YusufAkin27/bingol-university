# Yedek servisi: pg_dump/pg_restore + age + rclone + zamanlayici. postgres:16-alpine tabanli oldugundan
# verify-restore.sh gecici bir PostgreSQL sunucusunu (initdb) ayni imajda baslatabilir.
FROM postgres:16-alpine
# supercronic: SHA-256 DOGRULAMASI zorunlu (calisma zamaninda PGPASSWORD ve rclone kimlik bilgileriyle ayni ortamda calisir).
# Surum yukseltirken yeni ikililerin ozetlerini yayin sayfasindan/indirip `sha256sum` ile hesaplayip buraya yazin.
ARG SUPERCRONIC_VERSION=v0.2.33
ARG SUPERCRONIC_SHA256_AMD64=feefa310da569c81b99e1027b86b27b51e6ee9ab647747b49099645120cfc671
ARG SUPERCRONIC_SHA256_ARM64=f1f8585c66de020fef494dd636058f99949d108f569fef00016a1c8b9eb145b3
RUN apk add --no-cache age rclone zstd tar curl bash tzdata su-exec ca-certificates busybox-extras \
    && ARCH="$(uname -m)"; case "$ARCH" in x86_64) A=amd64; SHA="$SUPERCRONIC_SHA256_AMD64";; aarch64) A=arm64; SHA="$SUPERCRONIC_SHA256_ARM64";; *) echo "desteklenmeyen mimari: $ARCH" >&2; exit 1;; esac \
    && curl -fsSL -o /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${A}" \
    && echo "${SHA}  /usr/local/bin/supercronic" | sha256sum -c - \
    && chmod +x /usr/local/bin/supercronic
COPY lib.sh backup.sh restore.sh verify-restore.sh entrypoint.sh /opt/backup/
# Tek kullanici (postgres, uid 70): yedek dizini ona ait ve 750 (bos volume ilk baglamada bu sahipligi miras alir)
RUN chmod +x /opt/backup/*.sh && mkdir -p /var/backups /config/rclone /run/age-key \
    && chown postgres:postgres /var/backups && chmod 750 /var/backups && chmod 700 /run/age-key && chown postgres:postgres /run/age-key
ENV BACKUP_DIR=/var/backups UPLOADS_DIR=/data/uploads RCLONE_CONFIG=/config/rclone/rclone.conf
EXPOSE 9199
ENTRYPOINT ["/opt/backup/entrypoint.sh"]
