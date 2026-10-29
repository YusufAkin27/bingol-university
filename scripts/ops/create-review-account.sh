#!/usr/bin/env bash
# Google Play inceleme hesabini canli sunucuda olusturur / sifirlar / siler (ASCII, idempotent).
# Kullanim: bash scripts/ops/create-review-account.sh [--reset-password | --delete | --status]
#   (argumansiz)       hesap yoksa olusturur; VARSA dokunmaz (parola sifirlanmaz), eksik sozlesme onaylarini tamamlar
#   --reset-password   hesap varsa parolayi dosyadaki degere sifirlar (yoksa olusturur)
#   --delete           uygulamanin hesap silme mantigiyla siler (giris + DELETE /api/users/me -> anonimlestirme)
#   --status           yalniz durumu yazar (degisiklik yok)
# E-posta ve parola YEREL dosyadan okunur (EMAIL=..., PASSWORD=...); ssh STDIN ile gonderilir, komut satirinda
# GORUNMEZ ve hicbir yere yazdirilmaz. Ortam degiskenleri:
#   SECRETS_FILE (varsayilan ~/bu-secrets/play-review-account.txt), SSH_KEY (~/.ssh/bu_deploy_ed25519),
#   SSH_HOST (deploy@77.83.37.160), API_BASE (https://bukampus.com.tr), PG_CONTAINER (bu-postgres-1)
# Hesap normal kullanicidir (rol USER, ADMIN_EMAILS'e EKLENMEZ). Ayrinti: docs/store/PLAY_REVIEW_ACCOUNT.md
set -euo pipefail

MODE=create
case "${1:-}" in
  "") MODE=create;;
  --reset-password) MODE=reset;;
  --delete) MODE=delete;;
  --status) MODE=status;;
  *) echo "kullanim: $0 [--reset-password | --delete | --status]" >&2; exit 2;;
esac

SECRETS_FILE=${SECRETS_FILE:-$HOME/bu-secrets/play-review-account.txt}
SSH_KEY=${SSH_KEY:-$HOME/.ssh/bu_deploy_ed25519}
SSH_HOST=${SSH_HOST:-deploy@77.83.37.160}
API_BASE=${API_BASE:-https://bukampus.com.tr}
PG_CONTAINER=${PG_CONTAINER:-bu-postgres-1}

[ -r "$SECRETS_FILE" ] || { echo "sir dosyasi okunamadi: $SECRETS_FILE" >&2; exit 2; }
REV_EMAIL=$(grep -m1 '^EMAIL=' "$SECRETS_FILE" | cut -d= -f2- | tr -d '\r')
REV_PASSWORD=$(grep -m1 '^PASSWORD=' "$SECRETS_FILE" | cut -d= -f2- | tr -d '\r')
[ -n "$REV_EMAIL" ] && [ -n "$REV_PASSWORD" ] || { echo "dosyada EMAIL= / PASSWORD= yok" >&2; exit 2; }

# Uzak taraf: ilk 3 satir stdin'den (mod, e-posta, parola), kalani python kaynagi. Komut satirinda sir yok.
REMOTE='IFS= read -r REV_MODE; IFS= read -r REV_EMAIL; IFS= read -r REV_PASSWORD; export REV_MODE REV_EMAIL REV_PASSWORD; python3 -c "$(cat)"'

{
  printf '%s\n%s\n%s\n' "$MODE" "$REV_EMAIL" "$REV_PASSWORD"
  cat <<PYEOF
API_BASE = "$API_BASE"
PG = "$PG_CONTAINER"
PYEOF
  cat <<'PYEOF'
import hashlib, json, os, re, subprocess, sys, urllib.request, urllib.error

MODE = os.environ["REV_MODE"]
EMAIL = os.environ["REV_EMAIL"].strip().lower()
PW = os.environ["REV_PASSWORD"]
NAME = "Play İnceleme"
# Kayitta zorunlu onaylanan turler (LegalType.isSignupRequired); surum = tr guncel (aktif) belge
SIGNUP_TYPES = ("TERMS", "PRIVACY", "KVKK", "COMMUNITY_RULES")

if not re.fullmatch(r"[a-z0-9._-]+@[a-z0-9.-]*bingol\.edu\.tr", EMAIL):
    sys.exit("e-posta bingol.edu.tr alan adinda degil")
if len(PW.encode("utf-8")) > 72 or len(PW) < 8:
    sys.exit("parola 8 karakter ile 72 bayt arasinda olmali")


def sql(text):
    p = subprocess.run(
        ["docker", "exec", "-i", PG, "psql", "-U", "bingol", "-d", "bingol",
         "-v", "ON_ERROR_STOP=1", "-qtA", "-F", "|"],
        input=text, capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit("psql hatasi: " + p.stderr.strip()[:300])
    return p.stdout.strip()


def bcrypt_hash(pw):
    import bcrypt  # Spring BCryptPasswordEncoder ile ayni bicim: $2a$10$...
    return bcrypt.hashpw(pw.encode("utf-8"), bcrypt.gensalt(10, prefix=b"2a")).decode("ascii")


def find():
    row = sql("SELECT id, role, status, email_verified, admin_profile IS NULL FROM app_user WHERE email = '%s';" % EMAIL)
    return row.split("|") if row else None


def ensure_consents(uid):
    # Gercek kayit (LegalService.recordSignupConsent) ile ayni: her zorunlu tur icin guncel tr surum
    types = ",".join("'%s'" % t for t in SIGNUP_TYPES)
    return sql(
        "WITH ins AS (INSERT INTO legal_acceptance (user_id, doc_type, version) "
        "SELECT %s, type, version FROM legal_document WHERE active AND lang = 'tr' AND type IN (%s) "
        "ON CONFLICT (user_id, doc_type, version) DO NOTHING RETURNING 1) SELECT count(*) FROM ins;" % (uid, types))


def api(method, path, body=None, token=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(API_BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "bu-ops-review-account/1.0")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {}


row = find()

if MODE == "status":
    if row is None:
        print("durum: hesap YOK")
    else:
        print("durum: hesap var (id=%s rol=%s durum=%s dogrulandi=%s)" % tuple(row[:4]))
        print("onaylar:", sql("SELECT string_agg(doc_type || ' v' || version, ', ') FROM legal_acceptance WHERE user_id = %s;" % row[0]))
    sys.exit(0)

if MODE == "delete":
    if row is None:
        print("hesap yok; yapilacak bir sey yok")
        sys.exit(0)
    if row[2] != "ACTIVE":
        sys.exit("hesap ACTIVE degil (%s)" % row[2])
    code, res = api("POST", "/api/auth/login", {"email": EMAIL, "password": PW, "client": "mobile"})
    if code != 200 or "accessToken" not in res:
        sys.exit("giris basarisiz (HTTP %s): parola degismis olabilir; yonetici panelinden silin" % code)
    token = res["accessToken"]
    code, _ = api("DELETE", "/api/users/me", {"password": PW}, token)
    if code != 204:
        sys.exit("hesap silme basarisiz (HTTP %s)" % code)
    print("silindi (anonimlestirildi):", sql("SELECT 'durum=' || status FROM app_user WHERE id = %s;" % row[0]))
    sys.exit(0)

# create / reset
if row is None:
    h = bcrypt_hash(PW)
    sha = hashlib.sha256(EMAIL.encode("utf-8")).hexdigest()
    uid = sql(
        "INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, language, email_sha256) "
        "VALUES ('%s', '%s', '%s', TRUE, 'USER', 'ACTIVE', 'tr', '%s') RETURNING id;" % (EMAIL, h, NAME.replace("'", "''"), sha))
    uid = uid.splitlines()[0]
    n = ensure_consents(uid)
    print("olusturuldu: app_user=1, legal_acceptance=%s" % n)
else:
    uid = row[0]
    if row[1] != "USER":
        print("UYARI: hesap rolu USER degil (%s)" % row[1])
    if MODE == "reset":
        sql("UPDATE app_user SET password_hash = '%s' WHERE id = %s;" % (bcrypt_hash(PW), uid))
        print("parola sifirlandi (mevcut oturumlar sureleri dolana kadar acik kalabilir)")
    else:
        print("hesap zaten var; parola degistirilmedi")
    n = ensure_consents(uid)
    print("eksik sozlesme onayi eklendi: %s" % n)
    print("durum: id=%s rol=%s durum=%s dogrulandi=%s" % tuple(row[:4]))
PYEOF
} | ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=20 "$SSH_HOST" "$REMOTE"
