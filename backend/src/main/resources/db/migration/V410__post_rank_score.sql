-- V410: Kesfet "top" kapsami icin onceden hesaplanmis siralama puani (PostRankService her 5 dk gunceller).
-- Mevcut score kolonu (populer kapsami) degismez. Tasarim: docs/POSTS_DESIGN.md "Kesfet puanlama".
ALTER TABLE post ADD COLUMN rank_score DOUBLE PRECISION NOT NULL DEFAULT 0;
CREATE INDEX post410_rank_idx ON post (rank_score DESC, id DESC) WHERE deleted_at IS NULL AND hidden_at IS NULL;
