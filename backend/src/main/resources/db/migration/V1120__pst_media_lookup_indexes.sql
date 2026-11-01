-- FIX-P06 (A06#1): gonderi medyasi supurucusu ve hesap silme icin arama indeksleri.
-- Onceden post_media.storage_key indeksizdi: saatlik yetim taramasi her dosya icin seq scan yapiyordu (O(N^2)).
-- storage_key BENZERSIZ yapilmaz (yinelenen eski veri riski); yalniz arama indeksi.
-- Buyuk tabloda uretimde Flyway disinda CREATE INDEX CONCURRENTLY ile onceden kurulabilir (IF NOT EXISTS: ikinci kez zararsiz).
CREATE INDEX IF NOT EXISTS pst1120_media_storage_key ON post_media (storage_key);
CREATE INDEX IF NOT EXISTS pst1120_media_thumb_key ON post_media (thumb_key) WHERE thumb_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS pst1120_media_owner ON post_media (owner_id);
