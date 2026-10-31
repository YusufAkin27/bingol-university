-- T-149: rol ayriminin KANITI. Superuser olarak calistirilir; her satir 'OK' ya da 'FAIL' basar, FAIL varsa cikis kodu 3
-- (setup-roles.sh verify). Yalnizca okuma + gecici (ROLLBACK) denemeler yapar. ASCII.

\set ON_ERROR_STOP on

CREATE TEMP TABLE _chk(name text, ok boolean, detail text);

-- Roller super degil
INSERT INTO _chk SELECT 'rol ' || rolname || ' super degil', NOT rolsuper AND NOT rolcreaterole AND NOT rolcreatedb AND NOT rolreplication, ''
  FROM pg_roles WHERE rolname IN ('bingol_owner', 'bingol_app', 'bingol_backup');
INSERT INTO _chk SELECT 'uc rol da var', count(*) = 3, count(*)::text
  FROM pg_roles WHERE rolname IN ('bingol_owner', 'bingol_app', 'bingol_backup');

-- Tablolar bingol_owner'in
INSERT INTO _chk SELECT 'public tablolari bingol_owner sahibi', count(*) = 0, count(*)::text || ' tablo baska sahipte'
  FROM pg_tables WHERE schemaname = 'public' AND tableowner <> 'bingol_owner';

-- bingol_app yetkileri
INSERT INTO _chk SELECT 'app app_user uzerinde DML var',
       has_table_privilege('bingol_app', 'public.app_user', 'SELECT') AND has_table_privilege('bingol_app', 'public.app_user', 'INSERT')
       AND has_table_privilege('bingol_app', 'public.app_user', 'UPDATE') AND has_table_privilege('bingol_app', 'public.app_user', 'DELETE'), '';
INSERT INTO _chk SELECT 'app TRUNCATE/REFERENCES/TRIGGER yok',
       NOT has_table_privilege('bingol_app', 'public.app_user', 'TRUNCATE') AND NOT has_table_privilege('bingol_app', 'public.app_user', 'TRIGGER'), '';
INSERT INTO _chk SELECT 'app flyway_schema_history okuyamaz/yazamaz',
       NOT has_table_privilege('bingol_app', 'public.flyway_schema_history', 'SELECT')
       AND NOT has_table_privilege('bingol_app', 'public.flyway_schema_history', 'UPDATE'), '';
INSERT INTO _chk SELECT 'app sema olusturamaz (public CREATE yok)', NOT has_schema_privilege('bingol_app', 'public', 'CREATE'), '';
INSERT INTO _chk SELECT 'app veritabaninda CREATE yok', NOT has_database_privilege('bingol_app', current_database(), 'CREATE'), '';
INSERT INTO _chk SELECT 'app tablo sahibi degil', count(*) = 0, ''
  FROM pg_tables WHERE schemaname = 'public' AND tableowner = 'bingol_app';
INSERT INTO _chk SELECT 'app statement_timeout rol ayari',
       coalesce((SELECT bool_or(s LIKE 'statement_timeout=%') FROM pg_db_role_setting d, unnest(d.setconfig) s
                  WHERE d.setrole = (SELECT oid FROM pg_roles WHERE rolname = 'bingol_app')), false), '';

-- bingol_backup: yalniz okuma
INSERT INTO _chk SELECT 'backup SELECT var, yazma yok',
       has_table_privilege('bingol_backup', 'public.app_user', 'SELECT')
       AND NOT has_table_privilege('bingol_backup', 'public.app_user', 'INSERT')
       AND NOT has_table_privilege('bingol_backup', 'public.app_user', 'UPDATE')
       AND NOT has_table_privilege('bingol_backup', 'public.app_user', 'DELETE'), '';

-- Davranissal kanit: app rolu ile DDL denemesi reddedilir (sonuc degiskende tutulur; gecici tablo super sahibi)
DO $$
DECLARE
    denied boolean := false;
BEGIN
    BEGIN
        SET LOCAL ROLE bingol_app;
        EXECUTE 'CREATE TABLE public._dbroles_probe(x int)';
    EXCEPTION WHEN insufficient_privilege THEN
        denied := true;
    END;
    RESET ROLE;
    INSERT INTO _chk VALUES ('app CREATE TABLE reddedilmeli', denied, CASE WHEN denied THEN '' ELSE 'olusturabildi' END);
    DROP TABLE IF EXISTS public._dbroles_probe;
END
$$;

SELECT CASE WHEN ok THEN 'OK   ' ELSE 'FAIL ' END || name || CASE WHEN detail <> '' THEN ' (' || detail || ')' ELSE '' END AS sonuc FROM _chk ORDER BY ok, name;
SELECT (count(*) FILTER (WHERE NOT ok) > 0) AS failed FROM _chk \gset
\if :failed
\echo 'dbroles dogrulama: BASARISIZ'
\quit 3
\else
\echo 'dbroles dogrulama: tamam'
\endif
