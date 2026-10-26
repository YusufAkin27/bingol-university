# --- derleme (bagimlilik katmani onbellege alinir) ---
FROM maven:3-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# --- calistirma (yalnizca JRE, root olmayan kullanici) ---
FROM eclipse-temurin:17-jre
WORKDIR /app
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
