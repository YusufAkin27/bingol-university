-- 20 bin kullanicilik SENTETIK veri uretici (YALNIZ gelistirme/test veritabani). docs/PERFORMANCE.md "20k olcek"
--
-- Calistirma (backend en az bir kez acilip Flyway semayi kurmus olmali; CRYPTO_MIGRATE_MESSAGES=false onerilir):
--   docker compose -p bu_dbscale exec -T postgres psql -U bingol -d bingol -v confirm=I_AM_DEV_ONLY -f - < scripts/perf/seed-20k.sql
--
-- Koruma: 'confirm' degiskeni yoksa VEYA seed disi 50'den fazla kullanici varsa (uretim benzeri) betik durur.
-- Tekrar calistirilabilir: once onceki sentetik veriyi (seed%@bingol.edu.tr) siler.
-- Ayarlar (psql -v ile): users=20000 msgs_per_conv=20 events_per_user=150 notifs_per_user=40

\set ON_ERROR_STOP on
\if :{?users}
\else
  \set users 20000
\endif
\if :{?msgs_per_conv}
\else
  \set msgs_per_conv 20
\endif
\if :{?events_per_user}
\else
  \set events_per_user 150
\endif
\if :{?notifs_per_user}
\else
  \set notifs_per_user 40
\endif
\if :{?confirm}
\else
  \set confirm NO
\endif

-- Koruma (psql degiskenleri $$ icinde acilmaz, bu yuzden \if ile)
SELECT (:'confirm' = 'I_AM_DEV_ONLY') AS confirmed \gset
\if :confirmed
\else
  \echo 'seed-20k: -v confirm=I_AM_DEV_ONLY gerekli (yalniz gelistirme veritabani). Durduruldu.'
  \quit
\endif
SELECT (count(*) <= 50) AS looks_dev FROM app_user WHERE email NOT LIKE 'seed%@bingol.edu.tr' \gset
\if :looks_dev
\else
  \echo 'seed-20k: gercek kullanici verisi var gibi gorunuyor. Durduruldu.'
  \quit
\endif

\timing on
BEGIN;
SET LOCAL statement_timeout = 0;
SET LOCAL synchronous_commit = off;

-- onceki sentetik veri (CASCADE ile bagli satirlar da gider)
DELETE FROM message WHERE sender_id IN (SELECT id FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr');
DELETE FROM conversation WHERE created_by IN (SELECT id FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr');
DELETE FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr';

-- 1) Kullanicilar (parola hash'i gecersiz: sentetik hesapla giris yapilamaz)
INSERT INTO app_user (email, password_hash, display_name, email_verified, created_at, department, class_year, faculty, last_seen_at)
SELECT 'seed' || g || '@bingol.edu.tr', '$2a$10$seedseedseedseedseedseedseedseedseedseedseedseedseeds',
       'Seed Kullanici ' || g, TRUE, now() - (random() * 365) * interval '1 day',
       (ARRAY['Bilgisayar Muh.','Hukuk','Tip','Ilahiyat','Egitim','Iktisat'])[1 + g % 6],
       (1 + g % 4)::smallint, (ARRAY['Muhendislik','Hukuk','Tip','Ilahiyat','Egitim','IIBF'])[1 + g % 6],
       now() - (random() * 30) * interval '1 day'
FROM generate_series(1, :users) g;

CREATE TEMP TABLE seed_u AS
SELECT id, row_number() OVER (ORDER BY id) AS n FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr';
CREATE UNIQUE INDEX ON seed_u (n);

-- 2) Birebir konusmalar: kullanici basina ~3 (n -> n+1, n+7, n+101)
INSERT INTO conversation (type, direct_key, created_by, created_at)
SELECT 'DIRECT', LEAST(a.id, b.id) || ':' || GREATEST(a.id, b.id), a.id, now() - (random() * 200) * interval '1 day'
FROM seed_u a CROSS JOIN (VALUES (1), (7), (101)) d(k)
JOIN seed_u b ON b.n = ((a.n - 1 + d.k) % :users) + 1
WHERE a.id <> b.id
ON CONFLICT (direct_key) DO NOTHING;

INSERT INTO conversation_member (conversation_id, user_id, role)
SELECT c.id, u, 'MEMBER' FROM conversation c, LATERAL unnest(string_to_array(c.direct_key, ':')::bigint[]) u
WHERE c.created_by IN (SELECT id FROM seed_u) AND c.direct_key IS NOT NULL
ON CONFLICT DO NOTHING;

-- 3) Mesajlar (acik metin: yalniz dev; sifreleme gocu kapali olmali)
INSERT INTO message (conversation_id, sender_id, client_id, body, created_at)
SELECT c.id, (string_to_array(c.direct_key, ':'))[1 + (s % 2)]::bigint, 'seed-' || c.id || '-' || s,
       'Sentetik mesaj ' || s || ' ' || repeat('x', 40 + (s % 60)),
       c.created_at + (s * interval '37 minutes')
FROM conversation c CROSS JOIN generate_series(1, :msgs_per_conv) s
WHERE c.created_by IN (SELECT id FROM seed_u) AND c.direct_key IS NOT NULL;

UPDATE conversation c SET last_message_id = m.mid, last_message_at = m.at
FROM (SELECT conversation_id, max(id) AS mid, max(created_at) AS at FROM message GROUP BY conversation_id) m
WHERE m.conversation_id = c.id AND c.created_by IN (SELECT id FROM seed_u);

-- yarisi okunmamis kalsin
UPDATE conversation_member cm SET last_read_message_id = COALESCE((
    SELECT max(id) FROM message m WHERE m.conversation_id = cm.conversation_id AND m.id % 2 = 0), 0)
WHERE cm.user_id IN (SELECT id FROM seed_u);

-- 4) Bildirimler (kullanici basina notifs_per_user; %60 okunmus)
INSERT INTO notification (user_id, type, title, body, read_at, created_at)
SELECT u.id, (ARRAY['NEWS','EVENT','MESSAGE','COMMUNITY'])[1 + s % 4], 'Sentetik bildirim ' || s, 'Govde ' || s,
       CASE WHEN s % 5 < 3 THEN now() - (random() * 20) * interval '1 day' END,
       now() - (random() * 60) * interval '1 day'
FROM seed_u u CROSS JOIN generate_series(1, :notifs_per_user) s;

-- 5) Analitik olaylari (45 gun) ve gunluk aktiflik
INSERT INTO analytics_event (user_id, name, screen, created_at)
SELECT u.id, CASE WHEN s % 10 = 0 THEN 'search' WHEN s % 7 = 0 THEN 'app_open' ELSE 'screen_view' END,
       (ARRAY['home','explore','chat','clubs','events','menu','profile'])[1 + s % 7],
       now() - (random() * 45) * interval '1 day'
FROM seed_u u CROSS JOIN generate_series(1, :events_per_user) s;

INSERT INTO activity_daily (user_id, day, opens)
SELECT u.id, (current_date - d), 1 + (u.n + d) % 5
FROM seed_u u CROSS JOIN generate_series(0, 60) d WHERE (u.n + d) % 3 = 0
ON CONFLICT DO NOTHING;

-- 6) Denetim kaydi
INSERT INTO admin_audit (admin_id, admin_email, method, path, status, ip, created_at)
SELECT NULL, 'seed-admin@bingol.edu.tr', 'POST', '/api/admin/sentetik/' || s, 200, '10.0.0.1', now() - (random() * 400) * interval '1 day'
FROM generate_series(1, 100000) s;

COMMIT;
\timing off
ANALYZE;

SELECT relname AS tablo, n_live_tup AS satir, pg_size_pretty(pg_total_relation_size(relid)) AS boyut
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 15;
