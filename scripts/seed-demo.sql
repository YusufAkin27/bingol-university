-- Demo verisi (yalnizca gelistirme): ~300 "demo.NNN@bingol.edu.tr" kullanicisi, gunluk etkinlik ve kullanim olaylari.
-- Idempotent: demo kullanicilar zaten varsa yeniden eklenmez (ON CONFLICT DO NOTHING).
-- Temizlik: scripts/seed-demo.sh --clean  (yalnizca demo.%@bingol.edu.tr kayitlari silinir; bagli satirlar CASCADE).
-- Fakulte/bolum adlari ACIKCA ornektir. Demo parola hash'i hicbir parolayla eslesmez (giris yapilamaz).

BEGIN;

INSERT INTO app_user (email, password_hash, display_name, email_verified, created_at, status, role,
                      faculty, department, class_year, language, last_seen_at)
SELECT
    format('demo.%s@bingol.edu.tr', lpad(i::text, 3, '0')),
    '!demo-hesap-giris-yapilamaz',
    (ARRAY['Deniz','Ece','Mert','Zeynep','Emre','Elif','Kerem','Sena','Arda','Naz','Berk','Ilayda',
           'Yusuf','Asli','Omer','Beyza','Cem','Defne','Tolga','Melis'])[1 + (i % 20)]
      || ' ' ||
    (ARRAY['Demo','Ornek','Test','Deneme','Numune'])[1 + ((i / 20) % 5)] || ' ' || i,
    (i % 10 <> 0),
    now() - (floor(90 * (1 - power(random(), 1.6))) || ' days')::interval - (random() * 20 || ' hours')::interval,
    CASE WHEN i % 43 = 0 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
    'USER',
    CASE WHEN i % 17 = 0 THEN NULL
         ELSE 'Ornek Fakulte ' || (ARRAY['A','B','C','D','E','F'])[1 + (i % 6)] END,
    CASE WHEN i % 17 = 0 THEN NULL
         ELSE 'Ornek Bolum ' || (ARRAY['A','B','C','D','E','F'])[1 + (i % 6)] || (1 + (i / 6) % 2) END,
    CASE WHEN i % 13 = 0 THEN NULL ELSE (1 + (i % 4))::smallint END,
    CASE WHEN i % 10 < 7 THEN 'tr' WHEN i % 10 < 9 THEN 'en' ELSE 'ar' END,
    now() - (random() * 30 || ' days')::interval
FROM generate_series(1, 300) AS i
ON CONFLICT (email) DO NOTHING;

UPDATE app_user SET suspended_reason = 'Demo: topluluk kurallari ihlali'
WHERE email LIKE 'demo.%@bingol.edu.tr' AND status = 'SUSPENDED' AND suspended_reason IS NULL;

-- Gunluk acilislar: kayit gununden bugune, yeni kullanicilarda sik, zamanla seyrek
INSERT INTO activity_daily (user_id, day, opens)
SELECT u.id, d::date, 1 + floor(random() * 4)::int
FROM app_user u
CROSS JOIN LATERAL generate_series(u.created_at::date, current_date, interval '1 day') AS d
WHERE u.email LIKE 'demo.%@bingol.edu.tr' AND u.email_verified
  AND random() < 0.10 + 0.45 * exp(-(d::date - u.created_at::date) / 18.0)
ON CONFLICT (user_id, day) DO NOTHING;

-- Olaylar: her aktif gun icin app_open + screen_view; ek olarak search ve mesaj/gonderi benzeri olaylar
INSERT INTO analytics_event (user_id, name, screen, props, created_at)
SELECT a.user_id, 'app_open', NULL, NULL,
       LEAST(now(), a.day + time '07:00' + random() * interval '14 hours')
FROM activity_daily a JOIN app_user u ON u.id = a.user_id
WHERE u.email LIKE 'demo.%@bingol.edu.tr'
  AND NOT EXISTS (SELECT 1 FROM analytics_event e WHERE e.user_id = u.id AND e.name = 'app_open' LIMIT 1);

INSERT INTO analytics_event (user_id, name, screen, props, created_at)
SELECT a.user_id, 'screen_view',
       (ARRAY['home','news','menu','events','communities','messages','profile','search'])[1 + floor(random() * 8)::int],
       NULL,
       LEAST(now(), a.day + time '07:00' + random() * interval '14 hours')
FROM activity_daily a JOIN app_user u ON u.id = a.user_id
CROSS JOIN generate_series(1, 3) AS k
WHERE u.email LIKE 'demo.%@bingol.edu.tr'
  AND NOT EXISTS (SELECT 1 FROM analytics_event e WHERE e.user_id = u.id AND e.name = 'screen_view' LIMIT 1);

INSERT INTO analytics_event (user_id, name, screen, props, created_at)
SELECT a.user_id,
       (ARRAY['search','bookmark_add','share_news','menu_view'])[1 + floor(random() * 4)::int],
       NULL, NULL,
       LEAST(now(), a.day + time '07:00' + random() * interval '14 hours')
FROM activity_daily a JOIN app_user u ON u.id = a.user_id
WHERE u.email LIKE 'demo.%@bingol.edu.tr' AND random() < 0.5
  AND NOT EXISTS (SELECT 1 FROM analytics_event e WHERE e.user_id = u.id AND e.name = 'search' LIMIT 1);

-- Cihazlar (platform dagilimi)
INSERT INTO device (user_id, fcm_token, platform)
SELECT u.id, 'demo-token-' || u.id, CASE WHEN u.id % 4 = 0 THEN 'IOS' ELSE 'ANDROID' END
FROM app_user u
WHERE u.email LIKE 'demo.%@bingol.edu.tr' AND u.email_verified AND u.id % 10 < 7
ON CONFLICT (fcm_token) DO NOTHING;

-- Sozlesme onaylari (yalnizca varsa)
INSERT INTO legal_acceptance (user_id, doc_type, version, accepted_at)
SELECT u.id, d.type, d.version, u.created_at
FROM app_user u
JOIN legal_document d ON d.active AND d.type IN ('TERMS', 'PRIVACY') AND d.lang = 'tr'
WHERE u.email LIKE 'demo.%@bingol.edu.tr'
ON CONFLICT DO NOTHING;

COMMIT;

SELECT count(*) AS demo_kullanici FROM app_user WHERE email LIKE 'demo.%@bingol.edu.tr';
