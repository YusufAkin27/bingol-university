-- Performans verisi (YALNIZCA test/gelistirme): 20k kullanici, 500k mesaj, 50k RSVP, 5k haber, 2k topluluk, 200k bildirim.
-- Hepsi "demoperf" onekli: e-posta demoperf.N@bingol.edu.tr, haber url https://demoperf.invalid/..., topluluk demoperf-c-N,
-- sohbet basligi demoperf-g-N / demoperf-ws-N, etkinlik basligi "demoperf ...". Temizlik: clean-perf.sql (seed.sh --clean).
-- Tum demoperf kullanicilarinin parolasi: Sifre1234 (asagidaki bcrypt, maliyet 10; gercek bir sirri degildir).
-- Idempotent degil: zaten varsa seed.sh atlar. Elle calistirmadan once clean-perf.sql ile temizleyin.

BEGIN;

-- ---------- kullanicilar ----------
INSERT INTO app_user (email, password_hash, display_name, email_verified, created_at, status, role,
                      faculty, department, class_year, language, last_seen_at)
SELECT
    format('demoperf.%s@bingol.edu.tr', i),
    '$2a$10$U7qbPTC2zxYI3i9kxLWfSuzJACZiAx.rCtlY9x.bI/J4llD/h0Sb6',
    (ARRAY['Deniz','Ece','Mert','Zeynep','Emre','Elif','Kerem','Sena','Arda','Naz'])[1 + (i % 10)]
      || ' Perf ' || i,
    TRUE,
    now() - (random() * 365 || ' days')::interval,
    'ACTIVE', 'USER',
    'Ornek Fakulte ' || (ARRAY['A','B','C','D','E','F'])[1 + (i % 6)],
    'Ornek Bolum ' || (ARRAY['A','B','C','D','E','F'])[1 + (i % 6)] || (1 + (i / 6) % 4),
    (1 + (i % 4))::smallint,
    CASE WHEN i % 10 < 7 THEN 'tr' WHEN i % 10 < 9 THEN 'en' ELSE 'ar' END,
    now() - (random() * 30 || ' days')::interval
FROM generate_series(1, 20000) AS i;

-- n (1..20000) -> gercek id eslemesi
CREATE TEMP TABLE _u AS
SELECT (substring(email FROM 'demoperf\.(\d+)@'))::int AS n, id
FROM app_user WHERE email LIKE 'demoperf.%@bingol.edu.tr';
ALTER TABLE _u ADD PRIMARY KEY (n);

-- ---------- haberler (5k) ----------
CREATE TEMP TABLE _w AS
SELECT ARRAY['universite','ogrenci','sinav','burs','yemek','kampus','kutuphane','etkinlik','konferans','mezuniyet',
             'kayit','akademik','takvim','duyuru','fakulte','proje','staj','erasmus','sempozyum','seminer',
             'laboratuvar','dekanlik','rektorluk','ders','program'] AS w;

INSERT INTO news_item (type, url, title, summary, content, image_url, published_date, fetched_at, hidden)
SELECT
    (ARRAY['HABER','DUYURU','ETKINLIK'])[1 + (i % 3)],
    'https://demoperf.invalid/n/' || i,
    initcap(w[1 + (i % 25)]) || ' ' || w[1 + ((i * 7) % 25)] || ' ' || w[1 + ((i * 3) % 25)] || ' hakkinda ' || i,
    w[1 + ((i * 5) % 25)] || ' ' || w[1 + ((i * 11) % 25)] || ' ' || w[1 + ((i * 13) % 25)] || ' bilgilendirme ozeti ' || i,
    repeat(w[1 + ((i * 2) % 25)] || ' ' || w[1 + ((i * 9) % 25)] || ' icerik metni. ', 60),
    NULL,
    current_date - (i / 5),
    now(),
    (i % 97 = 0)
FROM generate_series(1, 5000) AS i, _w;

-- ---------- bildirimler (200k) ----------
INSERT INTO notification (user_id, type, title, body, data, read_at, created_at)
SELECT u.id, (ARRAY['NEWS','EVENT','MESSAGE'])[1 + (i % 3)], 'demoperf bildirim ' || i, 'demoperf govde ' || i, NULL,
       CASE WHEN i % 10 < 3 THEN NULL ELSE now() - interval '1 hour' END,
       now() - ((200000 - i) * interval '20 seconds')
FROM generate_series(1, 200000) AS i
JOIN _u u ON u.n = 1 + (i % 20000);

-- ---------- sohbetler ----------
-- 15000 birebir: k ile k+1+(k%50) (kucuk id < buyuk id)
INSERT INTO conversation (type, direct_key, created_by, created_at)
SELECT 'DIRECT', ua.id || ':' || ub.id, ua.id, now() - interval '120 days'
FROM generate_series(1, 15000) AS k
JOIN _u ua ON ua.n = k
JOIN _u ub ON ub.n = k + 1 + (k % 50)
ORDER BY k;

-- 1000 grup: uyeler ((g*17 + j) % 20000) + 1, j < m, m = 5 + g%20
INSERT INTO conversation (type, title, created_by, created_at)
SELECT 'GROUP', 'demoperf-g-' || g, u.id, now() - interval '120 days'
FROM generate_series(1, 1000) AS g
JOIN _u u ON u.n = ((g * 17) % 20000) + 1
ORDER BY g;

-- 20 WebSocket grubu (her biri 25 uye: kullanici (w-1)*25+1 .. w*25)
INSERT INTO conversation (type, title, created_by, created_at)
SELECT 'GROUP', 'demoperf-ws-' || w, u.id, now() - interval '120 days'
FROM generate_series(1, 20) AS w
JOIN _u u ON u.n = (w - 1) * 25 + 1
ORDER BY w;

-- Konusma tanimlari: idx -> id, tur, parametre
CREATE TEMP TABLE _cdef AS
SELECT row_number() OVER (ORDER BY c.id) AS idx, c.id,
       CASE WHEN c.type = 'DIRECT' THEN 'D' ELSE 'G' END AS kind,
       CASE WHEN c.type = 'DIRECT' THEN (SELECT n FROM _u WHERE id = c.created_by)
            ELSE substring(c.title FROM 'demoperf-g-(\d+)')::int END AS p
FROM conversation c
WHERE c.created_by IN (SELECT id FROM _u) AND (c.type = 'DIRECT' OR c.title LIKE 'demoperf-g-%');
ALTER TABLE _cdef ADD PRIMARY KEY (idx);

-- uyelikler
INSERT INTO conversation_member (conversation_id, user_id, role, joined_at)
SELECT d.id, u.id, 'MEMBER', now() - interval '120 days'
FROM _cdef d
JOIN _u u ON u.n IN (d.p, d.p + 1 + (d.p % 50))
WHERE d.kind = 'D';

INSERT INTO conversation_member (conversation_id, user_id, role, joined_at)
SELECT d.id, u.id, CASE WHEN j = 0 THEN 'ADMIN' ELSE 'MEMBER' END, now() - interval '120 days'
FROM _cdef d
CROSS JOIN LATERAL generate_series(0, 4 + (d.p % 20)) AS j
JOIN _u u ON u.n = ((d.p * 17 + j) % 20000) + 1
WHERE d.kind = 'G';

INSERT INTO conversation_member (conversation_id, user_id, role, joined_at)
SELECT c.id, u.id, CASE WHEN u.n = (w - 1) * 25 + 1 THEN 'ADMIN' ELSE 'MEMBER' END, now() - interval '120 days'
FROM generate_series(1, 20) AS w
JOIN conversation c ON c.title = 'demoperf-ws-' || w
CROSS JOIN LATERAL generate_series((w - 1) * 25 + 1, w * 25) AS gs(x)
JOIN _u u ON u.n = gs.x;

-- ---------- mesajlar (500k) ----------
-- Dagilim carpik: dusuk idx'li konusmalar sicak (power 2). Gonderen: birebirde a/b, grupta ilk 5 uyeden biri.
INSERT INTO message (conversation_id, sender_id, client_id, body, created_at, hidden_at)
SELECT d.id,
       u.id,
       'demoperf-' || m.i,
       'demoperf mesaj ' || m.i || ' ' || repeat('merhaba ', 1 + (m.i % 12)),
       now() - ((500001 - m.i) * interval '15 seconds'),
       CASE WHEN m.i % 200 = 0 THEN now() ELSE NULL END
FROM (SELECT i, 1 + floor(16000 * power(random(), 2))::int AS idx FROM generate_series(1, 500000) AS i) m
JOIN _cdef d ON d.idx = LEAST(m.idx, 16000)
JOIN _u u ON u.n = CASE WHEN d.kind = 'D' THEN d.p + (m.i % 2) * (1 + (d.p % 50))
                        ELSE ((d.p * 17 + (m.i % 5)) % 20000) + 1 END
ORDER BY m.i;

-- WS gruplarina birer mesaj (son mesaj dolu olsun; listede gorunsun)
INSERT INTO message (conversation_id, sender_id, client_id, body, created_at)
SELECT c.id, m.user_id, 'demoperf-ws-init-' || c.id, 'demoperf ws baslangic', now()
FROM conversation c
JOIN conversation_member m ON m.conversation_id = c.id AND m.role = 'ADMIN'
WHERE c.title LIKE 'demoperf-ws-%';

-- konusmanin son mesaji (denormalize alanlar)
UPDATE conversation c SET last_message_id = x.mid, last_message_at = x.at
FROM (SELECT conversation_id, max(id) AS mid, max(created_at) AS at FROM message
      WHERE client_id LIKE 'demoperf-%' GROUP BY conversation_id) x
WHERE c.id = x.conversation_id;

-- okundu imleci: uyelerin %60'i son mesaja kadar okumus, kalani hic okumamis (okunmamis sayimi yuku)
UPDATE conversation_member cm SET last_read_message_id = c.last_message_id
FROM conversation c
WHERE c.id = cm.conversation_id AND c.last_message_id IS NOT NULL
  AND cm.user_id IN (SELECT id FROM _u) AND (cm.id % 10) < 6;

-- ---------- topluluklar (2k), uyeler, gonderiler ----------
INSERT INTO community (name, slug, description, category, join_policy, visibility, status, owner_id, created_at, updated_at)
SELECT 'demoperf-c-' || i, 'demoperf-c-' || i,
       'demoperf topluluk aciklamasi ' || i,
       (ARRAY['Spor','Sanat','Bilim','Kariyer','Sosyal'])[1 + (i % 5)],
       'OPEN', 'PUBLIC',
       CASE WHEN i % 20 = 0 THEN 'PENDING_REVIEW' ELSE 'ACTIVE' END,
       u.id, now() - (random() * 200 || ' days')::interval, now()
FROM generate_series(1, 2000) AS i
JOIN _u u ON u.n = 1 + ((i * 13) % 20000);

CREATE TEMP TABLE _cm AS
SELECT row_number() OVER (ORDER BY id) AS idx, id, owner_id FROM community WHERE slug LIKE 'demoperf-c-%';

INSERT INTO community_member (community_id, user_id, role, status)
SELECT c.id, c.owner_id, 'OWNER', 'ACTIVE' FROM _cm c;

INSERT INTO community_member (community_id, user_id, role, status)
SELECT c.id, u.id, 'MEMBER', 'ACTIVE'
FROM _cm c
CROSS JOIN LATERAL generate_series(1, 9) AS j
JOIN _u u ON u.n = 1 + ((c.idx * 31 + j * 1999) % 20000)
ON CONFLICT (community_id, user_id) DO NOTHING;

INSERT INTO community_post (community_id, author_id, content, created_at)
SELECT c.id, c.owner_id, 'demoperf gonderi ' || c.idx || '/' || j, now() - ((c.idx + j) * interval '3 minutes')
FROM _cm c CROSS JOIN generate_series(1, 5) AS j;

-- ---------- etkinlikler (3k) ve RSVP (50k) ----------
INSERT INTO user_event (title, description, starts_at, ends_at, location, community_id, created_by, status, created_at, updated_at)
SELECT 'demoperf etkinlik ' || i, 'demoperf etkinlik aciklamasi ' || i,
       now() + ((i % 120 - 60) * interval '1 day'), now() + ((i % 120 - 60) * interval '1 day') + interval '2 hours',
       'Konferans Salonu ' || (i % 7),
       CASE WHEN i % 3 = 0 THEN (SELECT id FROM _cm WHERE idx = 1 + (i % 2000)) ELSE NULL END,
       u.id, CASE WHEN i % 25 = 0 THEN 'PENDING_REVIEW' ELSE 'ACTIVE' END, now(), now()
FROM generate_series(1, 3000) AS i
JOIN _u u ON u.n = 1 + ((i * 7) % 20000);

CREATE TEMP TABLE _ev AS
SELECT row_number() OVER (ORDER BY id) - 1 AS idx, id FROM user_event WHERE title LIKE 'demoperf etkinlik %';

-- 3000 etkinlik x 17 kisi (j * 1201 mod 20000 farkli) ~= 51k
INSERT INTO event_rsvp (event_id, user_id, status, created_at)
SELECT e.id, u.id, CASE WHEN j % 4 = 0 THEN 'INTERESTED' ELSE 'GOING' END, now() - (j * interval '1 hour')
FROM _ev e
CROSS JOIN generate_series(0, 16) AS j
JOIN _u u ON u.n = 1 + ((e.idx * 7 + j * 1201) % 20000);

UPDATE user_event ue SET going_count = x.c
FROM (SELECT event_id, count(*) AS c FROM event_rsvp WHERE status = 'GOING' GROUP BY event_id) x
WHERE ue.id = x.event_id AND ue.title LIKE 'demoperf etkinlik %';

COMMIT;
