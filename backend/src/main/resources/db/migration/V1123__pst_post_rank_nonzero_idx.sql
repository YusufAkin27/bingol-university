-- FIX-P06 (A06#8): PostRankRepository.zeroOld ("created_at < :since AND rank_score <> 0") her puan turunda
-- (5 dk) post tablosunu seq-scan ediyordu. Kismi indeks yalniz puani sifir olmayan satirlari tutar (14 gunluk pencere
-- kadar, kucuk) ve sorgunun kosuluyla birebir eslesir. rank_score zaten post410_rank_idx'te indeksli oldugundan
-- guncelleme HOT olmama maliyeti degismez.
CREATE INDEX IF NOT EXISTS pst1123_post_rank_nonzero ON post (created_at) WHERE rank_score <> 0;
