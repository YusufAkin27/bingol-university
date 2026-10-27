-- Ogrenci sinifi: PREP, 1..6, MASTER, PHD (katalog grades); eski kullanicilarda null.
ALTER TABLE app_user ADD COLUMN grade VARCHAR(8);
