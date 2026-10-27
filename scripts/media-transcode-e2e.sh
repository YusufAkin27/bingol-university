#!/usr/bin/env bash
# Gercek ffmpeg ile donusturme dogrulamasi (Docker; yigina dokunmaz). Kullanim (repo kokunden):
#   bash scripts/with-lock.sh bash scripts/media-transcode-e2e.sh
# VideoTranscoder.transcodeCommand/probeCommand/posterCommand ile ayni argumanlari kullanir (degisirse ikisini esle).
# Dogrulanir: 1080p kaynak -> en fazla 720p, H.264 main, AAC, yuv420p, +faststart (moov mdat'tan once),
# sure korunur, ses akisi olmayan kaynakta da calisir, poster karesi uretilir, bozuk girdi hata verir.
set -euo pipefail
export MSYS_NO_PATHCONV=1
IMG="${FFMPEG_IMAGE:-jrottenberg/ffmpeg:6.1-alpine}"
CN=bu-trn-e2e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(mktemp -d)"; if command -v cygpath >/dev/null; then OUT="$(cygpath -m "$OUT")"; fi
trap 'docker rm -f "$CN" >/dev/null 2>&1 || true' EXIT
docker rm -f "$CN" >/dev/null 2>&1 || true

pass() { echo "OK   $*"; }
fail() { echo "FAIL $*" >&2; exit 1; }

run_ff() { docker run --rm --entrypoint ffmpeg -v "$CN-w":/w "$IMG" "$@"; }

docker volume create "$CN-w" >/dev/null
trap 'docker rm -f "$CN" >/dev/null 2>&1 || true; docker volume rm -f "$CN-w" >/dev/null 2>&1 || true' EXIT

echo "== kaynak videolar (1080p 5 sn sesli; 480p sessiz)"
run_ff -hide_banner -loglevel error -y -f lavfi -i testsrc2=size=1920x1080:rate=30 -f lavfi -i sine=frequency=440:sample_rate=44100 \
  -t 5 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac /w/in.mp4
run_ff -hide_banner -loglevel error -y -f lavfi -i testsrc2=size=854x480:rate=24 -t 3 -c:v libx264 -preset ultrafast -pix_fmt yuv420p /w/silent.mp4

transcode() { # transcode <girdi> <cikti>
  run_ff -hide_banner -nostdin -loglevel error -y -protocol_whitelist file -i "/w/$1" -t 120 \
    -map 0:v:0 -map "0:a:0?" -sn -dn -map_metadata -1 -vf "scale=-2:'min(720,ih)'" \
    -c:v libx264 -profile:v main -pix_fmt yuv420p -preset veryfast -b:v 1500k -maxrate 1800k -bufsize 3000k -threads 1 \
    -c:a aac -b:a 96k -ac 2 -movflags +faststart -f mp4 "/w/$2"
}
probe() { # probe <dosya> <anahtar...>
  docker run --rm --entrypoint ffprobe -v "$CN-w":/w "$IMG" -v error -protocol_whitelist file -select_streams "$2" \
    -show_entries "$3" -of default=noprint_wrappers=1 "/w/$1"
}

echo "== donusturme"
transcode in.mp4 out.mp4
transcode silent.mp4 out_silent.mp4

V="$(probe out.mp4 v:0 stream=codec_name,profile,width,height,pix_fmt)"
echo "$V" | grep -q 'codec_name=h264'  && pass "codec h264"  || fail "codec: $V"
echo "$V" | grep -Eq 'profile=(Main|77)'     && pass "profil main"  || fail "profil: $V"
echo "$V" | grep -q 'height=720'       && pass "720p (1080p kucultuldu)" || fail "yukseklik: $V"
echo "$V" | grep -q 'width=1280'       && pass "genislik 1280 (cift)" || fail "genislik: $V"
echo "$V" | grep -q 'pix_fmt=yuv420p'  && pass "yuv420p" || fail "pix_fmt: $V"
A="$(probe out.mp4 a:0 stream=codec_name)"; echo "$A" | grep -q 'codec_name=aac' && pass "ses aac" || fail "ses: $A"
D="$(probe out.mp4 v:0 format=duration | sed -n 's/^duration=//p' | head -1)"
python -c "import sys; d=float('$D'); sys.exit(0 if 4.5<d<5.6 else 1)" && pass "sure korundu ($D sn)" || fail "sure: $D"
S="$(probe out_silent.mp4 v:0 stream=height)"; echo "$S" | grep -q 'height=480' && pass "480p yukseltilmedi" || fail "yukseltme: $S"
N="$(probe out_silent.mp4 a:0 stream=codec_name)"; [ -z "$N" ] && pass "sessiz kaynak sorunsuz" || fail "ses beklenmiyordu: $N"

echo "== faststart (moov, mdat'tan once)"
docker create --name "$CN" -v "$CN-w":/w "$IMG" >/dev/null
docker cp "$CN":/w/out.mp4 "$OUT/out.mp4"
if python -c "import sys; d=open(sys.argv[1],'rb').read(); pm=d.find(b'moov'); pd=d.find(b'mdat'); sys.exit(0 if 0 < pm < pd else 1)" "$OUT/out.mp4"; then
  pass "moov mdat'tan once"
else
  fail "faststart yok"
fi

echo "== poster karesi"
run_ff -hide_banner -nostdin -loglevel error -y -protocol_whitelist file -i /w/out.mp4 -map 0:v:0 \
  -vf "thumbnail=60,scale=-2:'min(720,ih)'" -frames:v 1 -an -q:v 3 -f image2 /w/poster.jpg
docker cp "$CN":/w/poster.jpg "$OUT/poster.jpg"
python -c "d=open(r'$OUT/poster.jpg','rb').read(); import sys; sys.exit(0 if d[:2]==b'\xff\xd8' and len(d)>1000 else 1)" \
  && pass "poster JPEG uretildi" || fail "poster"

echo "== bozuk girdi hata vermeli"
docker run --rm --entrypoint sh -v "$CN-w":/w "$IMG" -c 'head -c 3000 /dev/urandom > /w/bad.mp4'
if transcode bad.mp4 bad_out.mp4 >/dev/null 2>&1; then fail "bozuk girdi kabul edildi"; else pass "bozuk girdi reddedildi (cikis != 0)"; fi

echo; echo "MEDIA TRANSCODE E2E BASARILI"
