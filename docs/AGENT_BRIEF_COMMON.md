# Ajanlar için ortak kurallar

Bu dosya `docs/WORK_PLAN.md` içindeki tüm görevler (T1–T20) için geçerlidir. Önce `CLAUDE.md`'yi, sonra bu dosyayı, sonra kendi görev bölümünü (`WORK_PLAN.md` içinde `## T<n>`) oku.

## Çalışma ortamı
- Sen bir **git worktree**'desin (repo kökü). `main`'e dokunma, push YAPMA; işin bitince kendi dalında `git add -A && git commit` (ASCII mesaj, sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`).
- Java 8 yerelde; **Maven/Java 17 yalnızca Docker'da**: `cd backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test`.
- **Kendi yığının**: worktree kökünde `.env` oluştur (gitignored): `DB_PASSWORD=testpw123`, `JWT_SECRET=test-secret-test-secret-test-secret-9999`, `ADMIN_PASSWORD=adminpw123`, `ADMIN_EMAILS=boss@bingol.edu.tr,admin1@bingol.edu.tr`, `BACKEND_PORT=<görevine atanan port>`, **bellek tasarrufu için** `BACKEND_MEM_LIMIT=512m` ve `JAVA_TOOL_OPTIONS=-Xmx300m -XX:+UseSerialGC` (ana makinede boş RAM çok az; yük/performans testi yapan görev bunu yükseltebilir). Sonra `export COMPOSE_PROJECT_NAME=<görevine atanan ad> BACKEND_PORT=<port>; docker compose up -d --build postgres redis backend` (web servisini BAŞLATMA). Sağlık: `curl localhost:<port>/actuator/health`. İşin bitince `docker compose down -v`. Başka ajanların portlarına/proje adlarına DOKUNMA.
- Duman betikleri: `BASE=http://localhost:<port> ./scripts/smoke.sh` (+ `smoke-support.sh`, `smoke-search.sh`, `smoke-messaging.sh`, `SKIP_REMINDER=1 smoke-communities-events.sh`, `smoke-admin.sh`, `SLOW=1 node scripts/ws-test.js`). Betikler arasında `docker compose exec -T redis redis-cli flushall` (kayıt ucu IP başına saatte 10 ile sınırlı). Kullanıcı hazırlamak için `scripts/make-user.sh` (BASE ve proje adı env'iyle).
- Bash heredoc'lar bu ortamda sık bozuluyor ve terminal UTF-8 (Türkçe/Arapça) göndermiyor: dosyaları **Write/Edit** ile yaz; betiklerde ASCII kullan. Python yok; bash/node.

## Kod kuralları (özet; ayrıntı CLAUDE.md)
- Controller → Service → Repository; DTO record'ları; entity'ler API'ye çıkmaz. Spring Data depoları **üst düzey dosyada**; bean adı çakışmasına dikkat (modül öneki).
- **Flyway:** yalnızca görevine ayrılan sürüm aralığı; uygulanmış migration'ı DEĞİŞTİRME; **indeks/kısıt adları tüm şemada benzersiz** (modül öneki). `ddl-auto=validate`.
- **Yeni hata kodu = `messages.properties`, `messages_en.properties`, `messages_ar.properties` üçünde çeviri.** Bildirimler alıcının dilinde (`NotificationService.sendTemplated/sendLocalized`); yeni şablonlar 3 dilde.
- Rate limit zorunlu (`RateLimiter`) tüm yazma uçlarında; yetki kontrolleri servis katmanında; IDOR için başkasının kaynağına 404 (varlığı sızdırma).
- Kişisel veri tutan yeni modül `DataExporter` ekler; silinen/askıdaki kullanıcı davranışı düşünülür.
- Yorumlar kısa Türkçe, "neden"i anlatır. Dosyalar UTF-8 BOM'suz.

## Kalite kapıları (hepsi geçmeden bitirme)
1. `mvn -B test` yeşil (`contextLoads` dahil; H2'de PostgreSQL'e özel native sorgular çalışmaz → duman betiğiyle doğrula).
2. Kendi alanın için **yeni duman/uçtan uca betiği** (`scripts/<alan>-*.sh` veya `.js`), tekrar çalıştırılabilir (idempotent), ASCII.
3. **Mevcut tüm duman betikleri** geçmeye devam eder (regresyon yok).
4. Test yazarken: önce testi yaz, hatayı gör, sonra düzelt. Bulduğun her hata için regresyon testi bırak.

## Sınırlar
- Yalnızca görevinin "Sahip olduğun dosyalar" listesinde çalış. Başka alanda hata bulursan **düzeltme; raporda yeniden üretim adımlarıyla bildir**. Ortak dosyalarda (`SecurityConfig`, `pom.xml`, `application.properties`, `messages*.properties`) yalnızca gereken minimum satırı ekle (merge'de çakışmayı azaltmak için ekleme bloklarını dosya SONUNA, görev başlığıyla yap).
- Gizli bilgi yazma; gerçek dış servise (SMTP/FCM) bağlanma.

## Rapor biçimi (≤ 12 satır)
Yapılanlar · çalıştırdığın komutların GERÇEK sonuçları (test sayıları, betik çıktıları) · bulunan/düzeltilen hatalar (öncelik sırasıyla) · bulunup düzeltilmeyen sorunlar (yeniden üretim adımıyla) · varsayımlar/sapmalar · dal adı.
