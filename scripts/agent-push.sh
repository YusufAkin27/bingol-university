#!/usr/bin/env bash
# Ajanlar icin guvenli commit+push: tek seferde bir ajan, yalnizca verilen yollar eklenir.
# Kullanim: scripts/agent-push.sh "<commit mesaji>" <yol1> [yol2 ...]
# Ornek:   scripts/agent-push.sh "Web: kullanici yonetimi sayfasi" web/src/pages/admin/UsersPage.tsx web/src/i18n
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "kullanim: $0 \"mesaj\" yol [yol ...]" >&2
  exit 2
fi

MSG="$1"
shift

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
LOCK="$ROOT/.git/agent-push.lock"

# Basit kilit (mkdir atomiktir); 10 dk bekler, bayat kilidi (15 dk) kirar
tries=0
until mkdir "$LOCK" 2>/dev/null; do
  if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +15 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null || true
    continue
  fi
  tries=$((tries + 1))
  if [ "$tries" -gt 120 ]; then
    echo "kilit alinamadi (10 dk); sonra tekrar deneyin" >&2
    exit 3
  fi
  sleep 5
done
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

# Sir ve derleme ciktisi korumasi
for p in "$@"; do
  case "$p" in
    *.env|*/.env|*.p8|*.pem|*.jks|*.keystore|*/node_modules*|*/target/*|*/build/*|*/dist/*|*.apk|*.aab)
      echo "REDDEDILDI: sir/derleme ciktisi eklenemez: $p" >&2
      exit 4
      ;;
  esac
done

git add -- "$@"

if git diff --cached --quiet; then
  echo "eklenecek degisiklik yok (zaten commitli); push deneniyor"
else
  git commit -q -m "$MSG

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
  echo "commit tamam"
fi

# Tum ajanlar ayni calisma agacini ve ayni yerel dali paylasir; uzak dal normalde yerelin atasidir.
# Rebase (autostash, baskalarinin kaydedilmemis dosyalarini gecici gizler) yalnizca uzak dal ilerlediyse yapilir.
git fetch -q origin "$BRANCH"
if ! git merge-base --is-ancestor "origin/$BRANCH" HEAD; then
  echo "uzak dal ilerlemis; rebase yapiliyor"
  git pull --rebase --autostash -q origin "$BRANCH" || {
    echo "pull --rebase cakisti; elle cozum gerekir: git status" >&2
    git rebase --abort 2>/dev/null || true
    exit 5
  }
fi
git push -q origin "$BRANCH"
echo "push tamam: $(git rev-parse --short HEAD) -> origin/$BRANCH"
