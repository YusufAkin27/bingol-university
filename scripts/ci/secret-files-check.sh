#!/usr/bin/env bash
# CI kapisi (CD1): git'e girmis (takip edilen) dosyalar arasinda sir dosyasi var mi?
# Kullanim (repo kokunden): bash scripts/ci/secret-files-check.sh
# Cikis: 0 temiz, 1 sir adayi bulundu. Icerik taramasi (gitleaks) ayri is akisindadir; bu betik ad/uzanti + ozel anahtar basligi bakar.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

fail=0
# Takip edilen dosya adlari: .env (ornek dosyalar haric), anahtar/sertifika, dagitim kimlik bilgileri
bad="$(git ls-files | grep -E -i \
  -e '(^|/)\.env$' \
  -e '(^|/)\.env\.(prod|staging|local|production)$' \
  -e '(^|/)\.deploy\.env$' \
  -e '(^|/)\.deploy/' \
  -e '\.(pem|key|p8|p12|pfx|jks|keystore)$' \
  -e '(^|/)id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$' \
  -e '(^|/)bu_(deploy|ci)_ed25519' \
  -e '(^|/)rclone\.conf$' \
  -e '(^|/)(generated-secrets|service-account)[^/]*$' \
  || true)"
if [ -n "$bad" ]; then
  echo "HATA: takip edilen sir adayi dosyalar:" >&2
  printf '  %s\n' $bad >&2
  fail=1
fi

# Ozel anahtar basligi (yalniz metin dosyalari; test/ornek verileri icin yol istisnasi yok: gerekirse burada acikca listeleyin)
hits="$(git grep -l -I -E -e '-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----' -- . ':(exclude)scripts/ci/secret-files-check.sh' ':(exclude)scripts/test-ci-deploy.sh' || true)"
if [ -n "$hits" ]; then
  echo "HATA: ozel anahtar basligi iceren dosyalar:" >&2
  printf '  %s\n' $hits >&2
  fail=1
fi

[ "$fail" = 0 ] && echo "TEMIZ: takip edilen dosyalarda sir adayi yok"
exit "$fail"
