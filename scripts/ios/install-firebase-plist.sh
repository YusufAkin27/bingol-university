#!/usr/bin/env bash
# GoogleService-Info.plist'i (Firebase iOS uygulamasindan indirilen) DOGRULAYIP mobile/ios/Runner/ altina koyar.
# Kullanim:
#   scripts/ios/install-firebase-plist.sh <GoogleService-Info.plist yolu>
#   scripts/ios/install-firebase-plist.sh --base64-env IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64   (CI: gizli degiskenden)
#   scripts/ios/install-firebase-plist.sh --check          (hedefte duran dosyayi yalniz dogrular)
# Dogrulamalar (hicbiri degeri YAZDIRMAZ; yalniz PROJECT_ID, BUNDLE_ID ve GOOGLE_APP_ID bicimi gosterilir):
#   - plist ayrisir; GOOGLE_APP_ID, GCM_SENDER_ID, API_KEY, PROJECT_ID, BUNDLE_ID var
#   - BUNDLE_ID == Xcode PRODUCT_BUNDLE_IDENTIFIER (tr.com.bukampus.app); degilse REDDEDER (yanlis uygulamaya
#     bagli plist ile push ve Firebase sessizce calismaz)
#   - GOOGLE_APP_ID "1:<sayi>:ios:<hex>" bicimli (android degil)
#   - mobile/android/app/google-services.json varsa PROJECT_ID ayni Firebase projesi mi (backend FCM hizmet hesabi tek
#     projedir; farkli projede push gitmez)
#   - Xcode projesinde "Bundle GoogleService-Info.plist" fazi var (plist pbxproj'a elle eklenmez, faz kopyalar)
#   - hedef dosya git tarafindan yok sayiliyor (commitlenmez)
# Cikis: 0 = yerlestirildi/gecerli, 1 = reddedildi, 2 = kullanim hatasi. Gereken: python3 (plistlib).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$ROOT/mobile/ios/Runner/GoogleService-Info.plist"
PBX="$ROOT/mobile/ios/Runner.xcodeproj/project.pbxproj"
ANDROID_JSON="$ROOT/mobile/android/app/google-services.json"
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c "import plistlib" >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "HATA: python3 gerekli" >&2; exit 2; }

MODE="${1:-}"
SRC=""
TMP=""
trap '[ -z "$TMP" ] || rm -f "$TMP"' EXIT
case "$MODE" in
  "") echo "kullanim: $0 <plist> | --base64-env <DEGISKEN> | --check" >&2; exit 2 ;;
  --check) SRC="$DEST" ;;
  --base64-env)
    VAR="${2:?degisken adi gerekli}"
    VAL="${!VAR:-}"
    [ -n "$VAL" ] || { echo "HATA: $VAR bos/tanimsiz" >&2; exit 1; }
    TMP="$(mktemp)"
    printf '%s' "$VAL" | base64 --decode > "$TMP" 2>/dev/null || { echo "HATA: $VAR gecerli base64 degil" >&2; exit 1; }
    SRC="$TMP" ;;
  *) SRC="$MODE" ;;
esac
[ -f "$SRC" ] || { echo "HATA: dosya yok: $SRC" >&2; exit 1; }

BUNDLE="$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.-]*;' "$PBX" | grep -v RunnerTests | head -1 | sed 's/.*= \(.*\);/\1/')"
[ -n "$BUNDLE" ] || { echo "HATA: pbxproj'ta bundle id okunamadi" >&2; exit 1; }

SRC="$SRC" BUNDLE="$BUNDLE" ANDROID_JSON="$ANDROID_JSON" "$PY" -I -X utf8 - <<'PYEOF'
import json, os, plistlib, re, sys

src, bundle, aj = os.environ['SRC'], os.environ['BUNDLE'], os.environ['ANDROID_JSON']
errs = []
try:
    with open(src, 'rb') as f:
        d = plistlib.load(f)
except Exception as e:  # noqa: BLE001
    print('HATA: plist ayrismiyor (' + type(e).__name__ + '): bu bir GoogleService-Info.plist degil', file=sys.stderr)
    sys.exit(1)
for k in ('GOOGLE_APP_ID', 'GCM_SENDER_ID', 'API_KEY', 'PROJECT_ID', 'BUNDLE_ID'):
    if not d.get(k):
        errs.append(k + ' eksik')
if d.get('BUNDLE_ID') and d['BUNDLE_ID'] != bundle:
    errs.append('BUNDLE_ID (%s) != Xcode bundle id (%s): Firebase iOS uygulamasini bu id ile ekleyin' % (d['BUNDLE_ID'], bundle))
app_id = str(d.get('GOOGLE_APP_ID', ''))
if app_id and not re.fullmatch(r'1:\d+:ios:[0-9a-f]+', app_id):
    errs.append('GOOGLE_APP_ID iOS bicimli degil (1:<no>:ios:<hex>): Android uygulamasinin dosyasi olabilir')
if os.path.isfile(aj):
    try:
        with open(aj, encoding='utf-8') as f:
            apid = json.load(f).get('project_info', {}).get('project_id')
        if apid and d.get('PROJECT_ID') and apid != d['PROJECT_ID']:
            errs.append('PROJECT_ID (%s) Android google-services.json projesiyle (%s) ayni degil' % (d['PROJECT_ID'], apid))
    except Exception:  # noqa: BLE001
        pass
if errs:
    for e in errs:
        print('HATA: ' + e, file=sys.stderr)
    sys.exit(1)
print('plist gecerli: PROJECT_ID=%s BUNDLE_ID=%s' % (d['PROJECT_ID'], d['BUNDLE_ID']))
PYEOF

# Xcode projesinde paketleme fazi (plist dosyasi pbxproj'a dogrudan eklenmez; yoksa Firebase paketlenmez)
if grep -q 'Bundle GoogleService-Info.plist (optional)' "$PBX"; then
  echo "Xcode: 'Bundle GoogleService-Info.plist' derleme fazi var"
else
  echo "HATA: pbxproj'ta 'Bundle GoogleService-Info.plist' fazi yok; plist uygulamaya paketlenmez" >&2
  exit 1
fi

if [ "$MODE" != "--check" ]; then
  mkdir -p "$(dirname "$DEST")"
  cp -f "$SRC" "$DEST"
  chmod 600 "$DEST" 2>/dev/null || true
  echo "Yerlestirildi: mobile/ios/Runner/GoogleService-Info.plist"
fi

# gitignore: asla commitlenmemeli
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$ROOT" check-ignore -q "mobile/ios/Runner/GoogleService-Info.plist"; then
    echo "git: dosya yok sayiliyor (commitlenmez)"
  else
    echo "HATA: mobile/ios/Runner/GoogleService-Info.plist .gitignore disinda; commitlemeyin ve .gitignore'u duzeltin" >&2
    exit 1
  fi
fi
echo "Sonraki: APNs .p8 anahtarini YALNIZ Firebase Console > Cloud Messaging > Apple app configuration'a yukleyin."
