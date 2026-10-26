#!/usr/bin/env bash
# T5 guvenlik denetimi: bagimlilik zafiyet taramasi (npm audit + Maven surum kontrolu).
# Agaizi varsa (npm registry / Maven Central erisilemezse) ilgili adim atlanir ve rapor edilir.
set -u
cd "$(dirname "$0")/../.." || exit 1

echo "=== web/: npm audit (uretim bagimliliklari) ==="
if (cd web && npm audit --omit=dev) 2>&1; then
  :
else
  echo "[info] npm audit sifirdan farkli cikis kodu dondurdu (bulunan zafiyet sayisi > 0 ise normaldir)"
fi

echo
echo "=== web/: npm audit (tum bagimliliklar, gelistirme dahil) ==="
(cd web && npm audit) 2>&1 || echo "[info] npm audit sifirdan farkli cikis kodu dondurdu (bulunan zafiyet sayisi > 0 ise normaldir)"

echo
echo "=== backend/: Maven bagimlilik surum kontrolu (versions-maven-plugin, Docker Maven 17) ==="
cd backend || exit 1
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/app" -w /app maven:3-eclipse-temurin-17 \
  mvn -B org.codehaus.mojo:versions-maven-plugin:2.17.1:display-dependency-updates 2>&1 | \
  grep -E "^\[INFO\]|ERROR" || echo "[info] Maven Central'a erisilemedi; surum kontrolu atlandi (ag yok)."

echo
echo "=== bitti: cikan surumleri docs/SECURITY_AUDIT.md 'Bagimlilik taramasi' bolumuyle karsilastirin ==="
