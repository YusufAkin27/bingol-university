-- V72'de SMALLINT acilmisti; entity int bekliyor (ddl-auto=validate). Uygulanmis migration degistirilmez.
ALTER TABLE club_join_question ALTER COLUMN sort_order TYPE INTEGER;
