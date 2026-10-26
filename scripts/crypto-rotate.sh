#!/usr/bin/env bash
# Ana anahtar rotasyonu yardimcisi (yonetici JWT'si gerekir).
# 1) Yeni anahtar uretin ve CRYPTO_MASTER_KEYS'e SONA ekleyin:   ./scripts/crypto-rotate.sh newkey
# 2) Uygulamayi yeniden baslatin (eski anahtar listede KALSIN; yeni anahtar aktif olur)
# 3) DEK'leri yeni anahtarla sarin:     BASE=... TOKEN=<admin access token> ./scripts/crypto-rotate.sh rewrap [anahtarId]
# 4) Durumu gorun (eski anahtarla sarili 0 olmali):   ... ./scripts/crypto-rotate.sh status
# 5) Yalniz status'ta eski anahtar sayisi 0 ise eski anahtari listeden cikarin. Eski anahtari YEDEKTEN silmeyin
#    (eski veritabani yedeklerini acmak icin gerekir).
set -u
BASE=${BASE:-http://localhost:8080}
case "${1:-}" in
  newkey)
    ID=${2:-k$(date +%Y%m)}
    echo "$ID:$(openssl rand -base64 32)"
    echo "(bunu CRYPTO_MASTER_KEYS listesinin sonuna ekleyin: mevcut,$ID:...; ve guvenli yedekleyin)" >&2 ;;
  rewrap)
    curl -s -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer ${TOKEN:?TOKEN gerekli}" \
      "$BASE/api/admin/crypto/rewrap" -d "{\"targetKeyId\":\"${2:-}\"}"; echo ;;
  status)
    curl -s -H "Authorization: Bearer ${TOKEN:?TOKEN gerekli}" "$BASE/api/admin/crypto/status"; echo ;;
  *) echo "kullanim: newkey [id] | rewrap [anahtarId] | status"; exit 1 ;;
esac
