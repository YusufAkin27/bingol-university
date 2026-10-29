-- Yuk testi icin EK sentetik veri (YALNIZ gelistirme/test veritabani). seed-20k.sql'den SONRA calistirin:
--   psql -U bingol -d bingol -v confirm=I_AM_DEV_ONLY -f seed-load-extra.sql
-- Uretir: yonetici hesabi, gercek bcrypt parolasi (giris yuku icin), 100 kulup + ~5000 uyelik, 200 etkinlik + RSVP,
-- kapasite yarisi etkinligi, 30 bin gonderi + begeni + takip, 3000 haber, bu aya menu, 21 anket (1'i oy yarisi).
-- Tekrar calistirilabilir: once onceki 'ldx' verisini siler.
\set ON_ERROR_STOP on
\if :{?confirm}
\else
  \set confirm NO
\endif
SELECT (:'confirm' = 'I_AM_DEV_ONLY') AS confirmed \gset
\if :confirmed
\else
  \echo 'seed-load-extra: -v confirm=I_AM_DEV_ONLY gerekli. Durduruldu.'
  \quit
\endif
SELECT (count(*) <= 50) AS looks_dev FROM app_user WHERE email NOT LIKE 'seed%@bingol.edu.tr' AND email <> 'ld.admin@bingol.edu.tr' \gset
\if :looks_dev
\else
  \echo 'seed-load-extra: gercek kullanici verisi var gibi. Durduruldu.'
  \quit
\endif

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gercek bcrypt parolasi icin (yalniz yuk/dev veritabani)
\timing on
BEGIN;
SET LOCAL statement_timeout = 0;
SET LOCAL synchronous_commit = off;

-- onceki ek veri
DELETE FROM poll WHERE title LIKE 'ldx %';
DELETE FROM event_rsvp WHERE event_id IN (SELECT id FROM user_event WHERE title LIKE 'ldx %');
DELETE FROM user_event WHERE title LIKE 'ldx %';
DELETE FROM community_member WHERE community_id IN (SELECT id FROM community WHERE slug LIKE 'ldx-%');
DELETE FROM community WHERE slug LIKE 'ldx-%';
DELETE FROM post WHERE body LIKE 'ldx %'; -- post_media CASCADE
DELETE FROM news_item WHERE url LIKE 'https://ldx.example/%';
DELETE FROM menu_day WHERE items LIKE 'ldx %';
DELETE FROM app_user WHERE email = 'ld.admin@bingol.edu.tr';

CREATE TEMP TABLE seed_u AS
SELECT id, row_number() OVER (ORDER BY id) AS n FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr';
CREATE UNIQUE INDEX ON seed_u (n);

-- 1) Yonetici + gercek parola ('LoadTest-2026!', bcrypt maliyet 10) tum sentetik kullanicilara
INSERT INTO app_user (email, password_hash, display_name, email_verified, role)
VALUES ('ld.admin@bingol.edu.tr', crypt('LoadTest-2026!', gen_salt('bf', 10)), 'LD Admin', TRUE, 'ADMIN');
UPDATE app_user SET password_hash = (SELECT password_hash FROM app_user WHERE email = 'ld.admin@bingol.edu.tr')
WHERE email LIKE 'seed%@bingol.edu.tr';

-- 2) Kulupler: 100 adet ACTIVE, ~5000 uyelik
INSERT INTO community (name, slug, description, category, join_policy, visibility, status, owner_id, created_at)
SELECT 'ldx Kulup ' || g, 'ldx-' || g, 'Yuk testi kulubu ' || g, (ARRAY['SPOR','SANAT','BILIM','SOSYAL'])[1 + g % 4],
       'OPEN', 'PUBLIC', 'ACTIVE', (SELECT id FROM seed_u WHERE n = g), now() - (g * interval '1 day')
FROM generate_series(1, 100) g;
INSERT INTO community_member (community_id, user_id, role, status)
SELECT c.id, (SELECT id FROM seed_u WHERE n = ((c.id * 37 + g * 101) % 20000) + 1), 'MEMBER', 'ACTIVE'
FROM community c CROSS JOIN generate_series(1, 50) g WHERE c.slug LIKE 'ldx-%'
ON CONFLICT DO NOTHING;
INSERT INTO community_member (community_id, user_id, role, status)
SELECT id, owner_id, 'OWNER', 'ACTIVE' FROM community WHERE slug LIKE 'ldx-%' ON CONFLICT DO NOTHING;

-- 3) Etkinlikler: 200 adet (gelecek 60 gun), RSVP ~20 bin
INSERT INTO user_event (title, description, starts_at, ends_at, location, capacity, going_count, community_id, created_by, status, created_at)
SELECT 'ldx Etkinlik ' || g, 'Yuk testi etkinligi ' || g, now() + ((g % 60) * interval '1 day') + interval '3 hours',
       now() + ((g % 60) * interval '1 day') + interval '5 hours', 'Salon ' || (g % 10), NULL, 0,
       (SELECT id FROM community WHERE slug = 'ldx-' || (1 + g % 100)), (SELECT id FROM seed_u WHERE n = g), 'ACTIVE', now() - interval '5 days'
FROM generate_series(1, 200) g;
INSERT INTO event_rsvp (event_id, user_id, status)
SELECT e.id, (SELECT id FROM seed_u WHERE n = ((e.id * 53 + g * 211) % 20000) + 1), 'GOING'
FROM user_event e CROSS JOIN generate_series(1, 100) g WHERE e.title LIKE 'ldx %'
ON CONFLICT DO NOTHING;
UPDATE user_event e SET going_count = (SELECT count(*) FROM event_rsvp r WHERE r.event_id = e.id AND r.status = 'GOING')
WHERE e.title LIKE 'ldx %';
-- Kapasite yarisi: kapasite 100, 90 dolu -> 10 koltuk (yarisci kullanicilar n=1000..1099; dolu: n=2000..2089)
INSERT INTO user_event (title, description, starts_at, ends_at, location, capacity, going_count, created_by, status, created_at)
SELECT 'ldx Kapasite Yarisi', 'Son 10 koltuk', now() + interval '2 days', now() + interval '2 days 2 hours', 'Salon', 100, 90,
       (SELECT id FROM seed_u WHERE n = 5), 'ACTIVE', now() - interval '1 day';
INSERT INTO event_rsvp (event_id, user_id, status)
SELECT (SELECT id FROM user_event WHERE title = 'ldx Kapasite Yarisi'), u.id, 'GOING' FROM seed_u u WHERE u.n BETWEEN 2000 AND 2089;

-- 4) Takip (~15/kullanici) ve gonderiler (30 bin)
INSERT INTO user_follow (follower_id, followee_id)
SELECT a.id, b.id FROM seed_u a CROSS JOIN generate_series(1, 15) g
JOIN seed_u b ON b.n = ((a.n + g * 131 - 1) % 20000) + 1 WHERE a.id <> b.id ON CONFLICT DO NOTHING;
INSERT INTO user_follow_stats (user_id, follower_count, following_count)
SELECT u.id, COALESCE((SELECT count(*) FROM user_follow f WHERE f.followee_id = u.id), 0),
       COALESCE((SELECT count(*) FROM user_follow f WHERE f.follower_id = u.id), 0)
FROM seed_u u ON CONFLICT (user_id) DO UPDATE SET follower_count = EXCLUDED.follower_count, following_count = EXCLUDED.following_count;

INSERT INTO post (author_id, body, like_count, created_at, score, rank_score)
SELECT (SELECT id FROM seed_u WHERE n = 1 + (g * 7919) % 20000), 'ldx Gonderi ' || g || ' ' || repeat('lorem ipsum ', 5 + g % 20),
       0, now() - (random() * 30) * interval '1 day', random() * 100, random() * 100
FROM generate_series(1, 30000) g;
INSERT INTO post_like (post_id, user_id)
SELECT p.id, (SELECT id FROM seed_u WHERE n = 1 + (p.id * 17 + g * 977) % 20000)
FROM post p CROSS JOIN generate_series(1, 3) g WHERE p.body LIKE 'ldx %' ON CONFLICT DO NOTHING;
INSERT INTO post_media (post_id, owner_id, kind, position, storage_key, content_type, width, height, bytes)
SELECT p.id, p.author_id, 'IMAGE', 0, 'ldx/' || p.id || '.jpg', 'image/jpeg', 1080, 1080, 200000 FROM post p WHERE p.body LIKE 'ldx %';
UPDATE post SET media_count = 1 WHERE body LIKE 'ldx %';
UPDATE post p SET like_count = (SELECT count(*) FROM post_like l WHERE l.post_id = p.id) WHERE p.body LIKE 'ldx %';

-- 5) Haber 3000, menu (bu ay)
INSERT INTO news_item (type, url, title, summary, content, image_url, published_date, fetched_at)
SELECT (ARRAY['HABER','DUYURU','ETKINLIK'])[1 + g % 3], 'https://ldx.example/' || g, 'ldx Baslik ' || g || ' universite kampus',
       'Ozet ' || g || ' ' || repeat('universite ', 6), repeat('Haber govdesi universite ogrenci kampus. ', 30), NULL,
       current_date - (g % 400), now()
FROM generate_series(1, 3000) g;
INSERT INTO menu_day (menu_date, items)
SELECT d::date, 'ldx Corba; Ana yemek; Pilav; Salata'
FROM generate_series(date_trunc('month', current_date), date_trunc('month', current_date) + interval '1 month - 1 day', interval '1 day') d
WHERE NOT EXISTS (SELECT 1 FROM menu_day m WHERE m.menu_date = d::date);

-- 6) Anketler: 20 genel + 1 oy yarisi (SINGLE, 3 secenek)
INSERT INTO poll (title, description, type, scope, anonymous, allow_change_vote, show_results, max_choices, status, created_by, opens_at)
SELECT 'ldx Anket ' || g, 'Yuk testi', 'SINGLE', 'GLOBAL', TRUE, TRUE, 'ALWAYS', 1, 'OPEN', (SELECT id FROM seed_u WHERE n = 1), now() - interval '1 hour'
FROM generate_series(1, 21) g;
INSERT INTO poll_option (poll_id, position, text)
SELECT p.id, o, 'Secenek ' || o FROM poll p CROSS JOIN generate_series(1, 3) o WHERE p.title LIKE 'ldx %';

COMMIT;
\timing off
ANALYZE;
SELECT 'users' AS k, count(*) FROM app_user UNION ALL SELECT 'communities', count(*) FROM community UNION ALL
SELECT 'members', count(*) FROM community_member UNION ALL SELECT 'events', count(*) FROM user_event UNION ALL
SELECT 'rsvp', count(*) FROM event_rsvp UNION ALL SELECT 'posts', count(*) FROM post UNION ALL SELECT 'likes', count(*) FROM post_like UNION ALL
SELECT 'follows', count(*) FROM user_follow UNION ALL SELECT 'news', count(*) FROM news_item UNION ALL SELECT 'messages', count(*) FROM message;
