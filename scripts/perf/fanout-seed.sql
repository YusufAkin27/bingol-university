-- 500 uyeli grup sohbeti olcum verisi (YALNIZ gelistirme/test veritabani). docs/PERFORMANCE.md "Sohbet dagitimi (W1-E)".
--
--   docker compose -p bu_w1e exec -T postgres psql -U bingol -d bingol -v confirm=I_AM_DEV_ONLY -f - < scripts/perf/fanout-seed.sql
--
-- fan%@bingol.edu.tr kullanicilari (gecersiz parola hash'i: girise kapali; olcum betigi JWT uretir) ve 'fanout-bench'
-- adli tek GROUP sohbeti. Tekrar calistirilabilir (onceki sentetik veri silinir). Ayar: -v members=500
-- Cikti: son satir "CONV=<id> FIRST=<ilk kullanici id> LAST=<son>" (fanout-500.js bunu okur).

\set ON_ERROR_STOP on
\if :{?members}
\else
  \set members 500
\endif
\if :{?confirm}
\else
  \set confirm NO
\endif

SELECT (:'confirm' = 'I_AM_DEV_ONLY') AS confirmed \gset
\if :confirmed
\else
  \echo 'fanout-seed: -v confirm=I_AM_DEV_ONLY gerekli (yalniz gelistirme veritabani). Durduruldu.'
  \quit
\endif
SELECT (count(*) <= 50) AS looks_dev FROM app_user WHERE email NOT LIKE 'fan%@bingol.edu.tr' \gset
\if :looks_dev
\else
  \echo 'fanout-seed: gercek kullanici verisi var gibi gorunuyor. Durduruldu.'
  \quit
\endif

BEGIN;
DELETE FROM notification WHERE user_id IN (SELECT id FROM app_user WHERE email LIKE 'fan%@bingol.edu.tr');
DELETE FROM conversation WHERE title = 'fanout-bench';
DELETE FROM device WHERE user_id IN (SELECT id FROM app_user WHERE email LIKE 'fan%@bingol.edu.tr');
DELETE FROM app_user WHERE email LIKE 'fan%@bingol.edu.tr';

INSERT INTO app_user (email, password_hash, display_name, email_verified)
SELECT 'fan' || g || '@bingol.edu.tr', '$2a$10$fanfanfanfanfanfanfanfanfanfanfanfanfanfanfanfanfanfa', 'Fan Kullanici ' || g, TRUE
FROM generate_series(1, :members) g;

INSERT INTO conversation (type, title, created_by)
SELECT 'GROUP', 'fanout-bench', min(id) FROM app_user WHERE email LIKE 'fan%@bingol.edu.tr';

INSERT INTO conversation_member (conversation_id, user_id, role)
SELECT (SELECT id FROM conversation WHERE title = 'fanout-bench'), u.id,
       CASE WHEN u.id = (SELECT min(id) FROM app_user WHERE email LIKE 'fan%@bingol.edu.tr') THEN 'ADMIN' ELSE 'MEMBER' END
FROM app_user u WHERE u.email LIKE 'fan%@bingol.edu.tr';
COMMIT;

SELECT 'CONV=' || (SELECT id FROM conversation WHERE title = 'fanout-bench')
       || ' FIRST=' || min(id) || ' LAST=' || max(id) AS seed_result
FROM app_user WHERE email LIKE 'fan%@bingol.edu.tr';
