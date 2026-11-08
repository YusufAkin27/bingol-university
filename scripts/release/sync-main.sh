#!/usr/bin/env bash
# main dalini kurar: backend agaci release dalindan, mobil agac feature dalindan.
# Varsayilan DRY-RUN: hicbir sey commit/push edilmez, yalniz degisecekler yazdirilir.
#
# Kullanim:
#   scripts/release/sync-main.sh [--dry-run] [--push] [--release-ref REF]
#                                [--feature-ref REF] [--main-ref REF]
#                                [--backend-paths "backend ..."] [--no-fetch]
#   --push : commit eder ve "origin main"e push eder (yalniz bu bayrakla)
# Ornek: scripts/release/sync-main.sh --release-ref deploy/release4-20261106
set -euo pipefail

RELEASE_REF="deploy/release4-20261106"
FEATURE_REF="feature/mobil-uygulama"
MAIN_REF="origin/main"
BACKEND_PATHS="backend"
DO_PUSH=0
DO_FETCH=1
# feature dalindan birebir alinacak yollar
MOBILE_PATHS=(mobile scripts/ios codemagic.yaml docs/IOS_RELEASE.md design/widget-previews)

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DO_PUSH=0 ;;
    --push) DO_PUSH=1 ;;
    --release-ref) RELEASE_REF="${2:?deger gerekli}"; shift ;;
    --feature-ref) FEATURE_REF="${2:?deger gerekli}"; shift ;;
    --main-ref) MAIN_REF="${2:?deger gerekli}"; shift ;;
    --backend-paths) BACKEND_PATHS="${2:?deger gerekli}"; shift ;;
    --no-fetch) DO_FETCH=0 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "HATA: bilinmeyen arguman: $1" >&2; exit 2 ;;
  esac
  shift
done

REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"

if [ "$DO_FETCH" = 1 ]; then
  git fetch origin --quiet || echo "UYARI: fetch basarisiz, yerel referanslarla devam" >&2
fi

for r in "$RELEASE_REF" "$FEATURE_REF" "$MAIN_REF"; do
  git rev-parse --verify --quiet "$r^{commit}" >/dev/null \
    || { echo "HATA: referans yok: $r" >&2; exit 1; }
done

WT="$(mktemp -d)"
cleanup() {
  cd "$REPO" 2>/dev/null || true
  git worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$WT" 2>/dev/null || true
  git worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "== main=$MAIN_REF ($(git rev-parse --short "$MAIN_REF")) release=$RELEASE_REF ($(git rev-parse --short "$RELEASE_REF")) feature=$FEATURE_REF ($(git rev-parse --short "$FEATURE_REF"))"
git worktree add --detach "$WT" "$MAIN_REF" >/dev/null
cd "$WT"

# ref'teki yolu birebir esitle: once main'dekini sil (artiklar gider), sonra ref'ten al
sync_path() {
  local ref="$1" p="$2"
  git rm -rfq --ignore-unmatch -- "$p"
  rm -rf -- "$p"
  if [ -n "$(git ls-tree --name-only "$ref" -- "$p")" ]; then
    git checkout "$ref" -- "$p"
  else
    echo "  (not: '$p' $ref icinde yok, main'den silindi)"
  fi
}

echo "== backend yollari <- $RELEASE_REF"
for p in $BACKEND_PATHS; do sync_path "$RELEASE_REF" "$p"; done
echo "== mobil yollari <- $FEATURE_REF"
for p in "${MOBILE_PATHS[@]}"; do sync_path "$FEATURE_REF" "$p"; done

git add -A
TREE="$(git write-tree)"

echo "== degisecekler (git diff --stat $MAIN_REF -> yeni agac)"
git diff --cached --stat "$MAIN_REF" | tail -n 40

# Dogrulama: mobil yollar feature ile birebir olmali
DIFF="$(git diff --stat "$FEATURE_REF" "$TREE" -- "${MOBILE_PATHS[@]}")"
if [ -n "$DIFF" ]; then
  echo "HATA: mobil yollar $FEATURE_REF ile birebir degil:" >&2
  echo "$DIFF" >&2
  exit 1
fi
echo "== dogrulama TAMAM: mobil yollar $FEATURE_REF ile birebir"

if git diff --cached --quiet "$MAIN_REF"; then
  echo "== main zaten guncel, yapilacak is yok"
  exit 0
fi

if [ "$DO_PUSH" != 1 ]; then
  echo "== DRY-RUN: commit/push yapilmadi (push icin --push)"
  exit 0
fi

git commit -q -m "main esitleme: backend $RELEASE_REF, mobil $FEATURE_REF

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
# commit sonrasi son dogrulama
DIFF2="$(git diff --stat "$FEATURE_REF" HEAD -- "${MOBILE_PATHS[@]}")"
[ -z "$DIFF2" ] || { echo "HATA: commit sonrasi fark var:" >&2; echo "$DIFF2" >&2; exit 1; }
git push origin HEAD:main
echo "== push edildi: $(git rev-parse --short HEAD) -> origin/main"
