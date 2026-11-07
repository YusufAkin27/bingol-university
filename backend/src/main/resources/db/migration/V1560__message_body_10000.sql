-- Sohbet mesaji ust siniri 2000 -> 10000 karakter (kod noktasi). Sifreli govde (BYTEA) zaten sinirsizdir;
-- yalniz duz metin yedek sutunu (sifreleme kapaliyken / gecis donemi) genisler. Genisletme tablo yeniden yazmaz.
ALTER TABLE message ALTER COLUMN body TYPE VARCHAR(10000);
