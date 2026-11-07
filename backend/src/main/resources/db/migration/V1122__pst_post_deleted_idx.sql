-- FIX-P06 (A06#12): silinen gonderilerin medyasi (PostMediaRepository.ofPostsDeletedBefore) ve kalici silme
-- (PostRetentionJob) yalniz deleted_at dolu satirlari tarar; kismi indeks cok kucuk kalir.
CREATE INDEX IF NOT EXISTS pst1122_deleted_at ON post (deleted_at) WHERE deleted_at IS NOT NULL;
