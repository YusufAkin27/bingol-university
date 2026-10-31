-- T-149 (A8-12): PostgreSQL rol ayrimi. Idempotent (tekrar calistirilabilir). ASCII.
--
--   bingol_owner  : sema sahibi, Flyway/DDL. Super DEGIL. Yalniz Flyway (DB_OWNER_USER) kullanir.
--   bingol_app    : uygulama calisma hesabi (DB_USER). Super DEGIL; yalniz DML (SELECT/INSERT/UPDATE/DELETE + sequence).
--                   Rol duzeyi statement_timeout / idle_in_transaction_session_timeout.
--   bingol_backup : salt-okunur (pg_dump). pg_read_all_data.
--
-- Calistirma (superuser = mevcut POSTGRES_USER, hedef veritabani baglantisi):
--   bash scripts/dbroles/setup-roles.sh            (parolalari ortamdan alir; docs/changes/ops.md T-149)
-- psql degiskenleri: owner_pw, app_pw, backup_pw, dbname, legacy_owner (varsayilan 'bingol' = eski super hesap).
--
-- ONCE STAGING: bu betik mevcut nesnelerin sahibini degistirir. Uretimde bakim penceresi + yedek sonrasi.

\set ON_ERROR_STOP on

-- 1) Roller (yoksa olustur, parolalari guncelle)
SELECT format('CREATE ROLE bingol_owner LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', :'owner_pw')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bingol_owner') \gexec
SELECT format('CREATE ROLE bingol_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', :'app_pw')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bingol_app') \gexec
SELECT format('CREATE ROLE bingol_backup LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', :'backup_pw')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bingol_backup') \gexec
SELECT format('ALTER ROLE bingol_owner PASSWORD %L', :'owner_pw') \gexec
SELECT format('ALTER ROLE bingol_app PASSWORD %L', :'app_pw') \gexec
SELECT format('ALTER ROLE bingol_backup PASSWORD %L', :'backup_pw') \gexec

-- 2) Rol duzeyi guvenlik ayarlari (uygulama 8 sn statement_timeout kuralini rol seviyesinde de tasir)
ALTER ROLE bingol_app SET statement_timeout = '8s';
ALTER ROLE bingol_app SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE bingol_app SET lock_timeout = '5s';
ALTER ROLE bingol_backup SET statement_timeout = '0';
ALTER ROLE bingol_backup SET default_transaction_read_only = on;

-- 3) Veritabani ve sema yetkileri
SELECT format('GRANT CONNECT ON DATABASE %I TO bingol_owner, bingol_app, bingol_backup', :'dbname') \gexec
SELECT format('GRANT CREATE, TEMPORARY ON DATABASE %I TO bingol_owner', :'dbname') \gexec
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO bingol_owner;
GRANT USAGE ON SCHEMA public TO bingol_app, bingol_backup;

-- 4) Mevcut nesnelerin sahibi: bingol_owner (yalniz public semasindaki tablo/sequence/view; eklenti nesnelerine dokunulmaz)
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.relkind, quote_ident(n.nspname) AS sch, quote_ident(c.relname) AS rel
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public'
           AND c.relkind IN ('r', 'p', 'S', 'v', 'm', 'f')
           AND pg_get_userbyid(c.relowner) <> 'bingol_owner'
           AND NOT EXISTS (SELECT 1 FROM pg_depend d
                            WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'e') -- eklenti uyesi degil
           -- sequence'ler kimlik kolonuna bagliysa (deptype 'i') tablo ile birlikte gider
           AND NOT (c.relkind = 'S' AND EXISTS (SELECT 1 FROM pg_depend d
                            WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'i'))
    LOOP
        EXECUTE format('ALTER %s %s.%s OWNER TO bingol_owner',
                       CASE r.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW'
                                      WHEN 'f' THEN 'FOREIGN TABLE' ELSE 'TABLE' END, r.sch, r.rel);
    END LOOP;
    -- Kullanici tanimli fonksiyonlar (eklenti fonksiyonlari haric)
    FOR r IN
        SELECT p.oid::regprocedure AS sig
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND pg_get_userbyid(p.proowner) <> 'bingol_owner'
           AND NOT EXISTS (SELECT 1 FROM pg_depend d
                            WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e')
    LOOP
        EXECUTE format('ALTER FUNCTION %s OWNER TO bingol_owner', r.sig);
    END LOOP;
END
$$;
ALTER SCHEMA public OWNER TO bingol_owner;

-- 5) bingol_app: yalniz DML. Flyway gecmisi ve sema degistirme YOK.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO bingol_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO bingol_app;
REVOKE ALL ON TABLE flyway_schema_history FROM bingol_app;
-- Sonradan Flyway (bingol_owner) ile olusacak nesneler icin varsayilan yetkiler
ALTER DEFAULT PRIVILEGES FOR ROLE bingol_owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bingol_app;
ALTER DEFAULT PRIVILEGES FOR ROLE bingol_owner IN SCHEMA public
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bingol_app;
ALTER DEFAULT PRIVILEGES FOR ROLE bingol_owner IN SCHEMA public
    GRANT SELECT ON TABLES TO bingol_backup;
ALTER DEFAULT PRIVILEGES FOR ROLE bingol_owner IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO bingol_backup;

-- 6) bingol_backup: salt-okunur (pg_dump tum tablo + sequence okuyabilmeli)
GRANT pg_read_all_data TO bingol_backup;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO bingol_backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO bingol_backup;

-- 7) Eski super hesap artik uygulamada KULLANILMAZ (DB_USER=bingol_app). Silinmez: POSTGRES_USER konteyner bootstrap
--    hesabidir ve acil durum erisimidir; ama uygulama/yedek/Flyway ona baglanmaz.
\echo 'dbroles: tamam. Dogrulama: psql -f scripts/dbroles/verify-roles.sql'
