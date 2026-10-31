# T-148 (A8-11): taban imajlar OZETLE (sha256) sabitlidir: ayni Dockerfile her derlemede ayni tabani alir, kayan etiket
# sessizce degismez. Etiket okunabilirlik icindir; Dependabot (docker) etiket + ozeti birlikte yukseltir.
# --- derleme (bagimlilik katmani onbellege alinir) ---
FROM maven:3-eclipse-temurin-17@sha256:b67db904974d04b9e6eba5b073ae227569ee1cae0d1f26be8993525291ef76dc AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# --- calistirma (yalnizca JRE, root olmayan kullanici) ---
FROM eclipse-temurin:17-jre@sha256:4faa9eaf440514dd4f7ef71fecb92526e13679aea039bed5d2fc98e885c60dee
WORKDIR /app
# ffmpeg/ffprobe: gonderi videosu yeniden kodlama (app.media.transcode.*, docs/MEDIA_PIPELINE.md). Minimal kurulum;
# imaj ~+150-250 MB. ffmpeg olmasa da uygulama calisir (donusturme otomatik kapanir).
# FFMPEG_VERSION bos = dagitimin guncel paketi (guvenlik duzeltmeleri gelir); sabitlemek icin tam Ubuntu paket surumunu
# verin (--build-arg FFMPEG_VERSION=7:6.1.1-3ubuntu5). Surum paket havuzundan kalkarsa derleme KIRILIR: varsayilan bos.
ARG FFMPEG_VERSION=
RUN apt-get update \
    && apt-get install -y --no-install-recommends "ffmpeg${FFMPEG_VERSION:+=$FFMPEG_VERSION}" \
    && rm -rf /var/lib/apt/lists/* \
    && ffmpeg -version | head -1
RUN useradd --system --uid 1001 --no-create-home app \
    && mkdir -p /data/uploads && chown -R app /data/uploads /app
COPY --from=build --chown=app /build/target/*.jar app.jar
USER app
ENV TZ=Europe/Istanbul \
    JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom"
EXPOSE 8080
VOLUME /data/uploads
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=5 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080 && printf "GET /actuator/health HTTP/1.0\r\n\r\n" >&3 && grep -q "\"UP\"" <&3' || exit 1
# exec: JVM PID 1 olur, SIGTERM ile graceful shutdown calisir
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
