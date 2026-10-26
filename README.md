<p align="center"><img src="docs/brand/logo-horizontal.png" alt="BÜ Kampüs" height="72"></p>

# BÜ Kampüs

Bingöl Üniversitesi öğrenci ve personeli için kampüs uygulaması ve web sitesi. Marka kılavuzu: [brand/README.md](brand/README.md).

- `backend/` — Spring Boot 4 (Java 17, Maven, JPA, Security, PostgreSQL, Redis)
- `mobile/`  — Flutter (iOS/Android)

## Backend
Docker gerekir: `cp .env.example .env` (degerleri doldurun) → `docker compose up -d --build` → http://localhost:8080/actuator/health
PostgreSQL + Redis + backend birlikte ayaga kalkar. Ayrintilar: CLAUDE.md. API planlari: docs/.

## Web (tanitim sitesi + yonetim paneli)
`web/` klasoru (React + TypeScript). Bkz. web/README.md.

## Mobile
Flutter uygulamasi `mobile/` altindadir (kayit/giris, haber, yemek, sohbet, kulup, etkinlik+QR, bildirim, arama, destek, profil). Derleme/calistirma (Windows, xcross ile iPhone dahil) ve mimari: [docs/MOBILE_UI.md](docs/MOBILE_UI.md); API rehberi: [docs/MOBILE_API_GUIDE.md](docs/MOBILE_API_GUIDE.md); push kurulumu: [docs/PUSH_SETUP.md](docs/PUSH_SETUP.md).
```
cd mobile
flutter test
flutter run --dart-define=API_BASE=http://<adres>:8080
```

## Hizli baslangic
```
cp .env.example .env        # DB_PASSWORD, JWT_SECRET, ADMIN_PASSWORD doldurun
docker compose up -d --build
# API: http://localhost:8080   Web (tanitim + /admin): http://localhost:${WEB_PORT:-8090}
./scripts/make-user.sh admin1@bingol.edu.tr "Yonetici"   # ADMIN_EMAILS listesindeki e-posta yonetici olur
./scripts/seed-demo.sh                                    # istege bagli: demo analitik verisi (--clean ile siler)
```
Duman testleri: `scripts/smoke*.sh`, `node scripts/ws-test.js` (bkz. CLAUDE.md).

## Dokumanlar
- CLAUDE.md — mimari, kurallar, komutlar
- docs/MVP.md, docs/API_PLAN.md, docs/ADMIN_API.md, docs/MESSAGING_DESIGN.md, docs/ONERILER.md, docs/CHANGELOG.md
- docs/MOBILE_API_GUIDE.md, docs/MOBILE_UI.md, docs/PUSH_SETUP.md, docs/MOBILE_PUSH.md, docs/DEPLOY.md (uretim), docs/PERFORMANCE.md, docs/changes/ (modul notlari)
