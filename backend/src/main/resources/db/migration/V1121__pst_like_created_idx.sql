-- FIX-P06 (A06#8): Kesfet puani son 24 saat begenilerini tek GROUP BY ile okur (PostRankRepository.recentLikesSince);
-- created_at indeksi olmadan post_like tam taranirdi. Buyuk tabloda uretimde CONCURRENTLY ile onceden kurulabilir.
CREATE INDEX IF NOT EXISTS pst1121_like_created ON post_like (created_at);
