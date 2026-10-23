# Bingöl Üniversitesi Projesi

- `backend/` — Spring Boot 4 (Java 17, Maven, JPA, Security, PostgreSQL, Redis)
- `mobile/`  — Flutter (Android)

## Backend
Docker gerekir: `cp .env.example .env` (degerleri doldurun) → `docker compose up -d --build` → http://localhost:8080/actuator/health
PostgreSQL + Redis + backend birlikte ayaga kalkar. Ayrintilar: CLAUDE.md. API planlari: docs/.

## Web (tanitim sitesi + yonetim paneli)
`web/` klasoru (React + TypeScript). Bkz. web/README.md.

## Mobile
Flutter SDK kurulu degilse once kurun. Ardindan:
```
cd mobile
flutter create --platforms=android --org edu.bingol --project-name bingol_mobile .
flutter run
```
(`flutter create .` mevcut lib/main.dart ve pubspec.yaml dosyalarini korur.)


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
- docs/MVP.md, docs/API_PLAN.md, docs/ADMIN_API.md, docs/MESSAGING_DESIGN.md, docs/ONERILER.md
