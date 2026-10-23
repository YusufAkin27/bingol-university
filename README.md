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

## Veri kaynakları ve zamanlayıcılar
- Haber/Duyuru/Etkinlik: bingol.edu.tr — her gece 00:00 (`news.sync.cron`)
- Yemek listesi: sks.bingol.edu.tr — ayın son günü 23:30 (`menu.sync.cron`)
- Veritabani bossa ilk acilista bir kez doldurulur; sonrasinda siteye yalnizca zamanlayicilar istek atar.
- Kaynak site degisir/ulasilamazsa hata verilmez; `GET /api/status` ilgili kaynagi `maintenance: true` yapar, mobil "bakimda" bandi gosterir ve eski veriler sunulur.

## API
`GET /api/news?type=HABER|DUYURU|ETKINLIK&page=0&size=20`, `GET /api/news/{id}`, `GET /api/menu?month=2026-10`, `GET /api/menu/today`, `GET /api/status`
Manuel tetikleme (kimlik dogrulama gerekir): `POST /api/admin/sync`, `POST /api/admin/sync-menu`

## Siradaki: mesajlasma
Bagimliliklar eklendi: WebSocket, Redis, Bucket4j (rate limit), JJWT. Uyelik/giris, mesajlasma ve rate limit henuz yazilmadi.
