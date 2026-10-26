#!/usr/bin/env bash
# Kod kalitesi taramasi: backend (JaCoCo) + web (vitest lcov) kapsamini SonarQube'a yukler.
# Onkosul: backend testleri `mvn test` ile kosulmus olmali (target/site/jacoco/jacoco.xml)
#          ve `cd web && npm run test:coverage` calismis olmali (web/coverage/lcov.info).
# Kullanim: scripts/sonar/run-sonar.sh   (ASCII; tekrar calistirilabilir)
set -u
cd "$(dirname "$0")/../.."
SONAR_URL=${SONAR_URL:-http://localhost:9000}
COMPOSE="docker compose -f scripts/sonar/docker-compose.sonar.yml"

# Elasticsearch icin gerekli (Docker Desktop / WSL2)
MSYS_NO_PATHCONV=1 wsl -d docker-desktop sysctl -w vm.max_map_count=262144 >/dev/null 2>&1 || true

$COMPOSE up -d
echo "SonarQube aciliyor..."
for i in $(seq 1 90); do
  st=$(curl -s "$SONAR_URL/api/system/status" | sed -n 's/.*"status":"\([A-Z_]*\)".*/\1/p')
  [ "$st" = "UP" ] && break
  sleep 5
done
[ "${st:-}" = "UP" ] || { echo "SonarQube acilmadi (son durum: ${st:-yok})"; exit 1; }

# Ilk giriste admin/admin: parolayi degistir, sonra belirtec uret
PW=${SONAR_ADMIN_PASSWORD:-Sonar!Pass2026x}
curl -s -u admin:admin -X POST "$SONAR_URL/api/users/change_password" \
  -d "login=admin&previousPassword=admin&password=$PW" >/dev/null 2>&1
TOKEN=$(curl -s -u "admin:$PW" -X POST "$SONAR_URL/api/user_tokens/generate" \
  -d "name=scan-$(date +%s)" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] || { echo "Belirtec uretilemedi"; exit 1; }

# Tarayici konteyneri host'taki SonarQube'a host.docker.internal ile ulasir
MSYS_NO_PATHCONV=1 docker run --rm -e SONAR_HOST_URL="http://host.docker.internal:9000" -e SONAR_TOKEN="$TOKEN" \
  -v "$(pwd -W 2>/dev/null || pwd):/usr/src" sonarsource/sonar-scanner-cli

echo "Rapor: $SONAR_URL/dashboard?id=bu-kampus (admin / $PW)"
echo "Ozet JSON: curl -s -u admin:$PW '$SONAR_URL/api/measures/component?component=bu-kampus&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,security_hotspots,reliability_rating,security_rating,sqale_rating'"
