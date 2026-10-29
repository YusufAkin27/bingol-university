-- RL1 olcum tohumu (YALNIZ test yigini): 700 kullanici (rl1uN@bingol.edu.tr, parola LoadTest-2026!) + admin.
-- Kullanim: psql -U bingol -d bingol -v confirm=I_AM_DEV_ONLY -f seed-rl1.sql
\if :{?confirm}
\else
  \echo 'seed-rl1: -v confirm=I_AM_DEV_ONLY gerekli. Durduruldu.'
  \quit
\endif
SELECT (count(*) = 0) AS empty_db FROM app_user WHERE email NOT LIKE 'rl1u%@bingol.edu.tr' AND email <> 'rl1.admin@bingol.edu.tr' \gset
\if :empty_db
\else
  \echo 'seed-rl1: gercek kullanici verisi var gibi. Durduruldu.'
  \quit
\endif
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DELETE FROM app_user WHERE email LIKE 'rl1u%@bingol.edu.tr' OR email = 'rl1.admin@bingol.edu.tr';
INSERT INTO app_user (email, password_hash, display_name, email_verified, role)
VALUES ('rl1.admin@bingol.edu.tr', crypt('LoadTest-2026!', gen_salt('bf', 10)), 'RL1 Admin', TRUE, 'ADMIN');
INSERT INTO app_user (email, password_hash, display_name, email_verified)
SELECT 'rl1u' || g || '@bingol.edu.tr', (SELECT password_hash FROM app_user WHERE email = 'rl1.admin@bingol.edu.tr'),
       'RL1 Kullanici ' || g, TRUE
FROM generate_series(1, 700) g;
ANALYZE;
SELECT count(*) AS users FROM app_user;
