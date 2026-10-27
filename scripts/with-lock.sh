#!/usr/bin/env bash
# Agir derlemeleri (Maven/Gradle/tam test paketi) siraya sokar: ayni anda cok sayida agir islem bellek bitirir.
# Kullanim: bash scripts/with-lock.sh <komut ...>
#   ornek: bash scripts/with-lock.sh bash -c 'cd backend && MSYS_NO_PATHCONV=1 docker run --rm ... mvn test'
LOCK="${LOCKDIR:-C:/xtmp/locks/heavy}"
mkdir -p "$(dirname "$LOCK")"
for _ in $(seq 1 240); do
  if mkdir "$LOCK" 2>/dev/null; then
    trap 'rmdir "$LOCK" 2>/dev/null' EXIT
    "$@"
    exit $?
  fi
  # 30 dakikadan eski (sahipsiz) kilidi temizle
  if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null
  fi
  sleep 15
done
echo "kilit alinamadi (60 dk bekledi)" >&2
exit 1
