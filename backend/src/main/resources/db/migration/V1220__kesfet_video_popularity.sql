-- V1220: Kesfet video/reels + izlenme puani + kullanici populerlik puani (docs/changes/post.md "Kesfet: tek siralama, video, reels").
-- Gonderi = 1 fotograf VEYA 1 video. kind: gonderinin ilk medyasinin turu (PHOTO | VIDEO); reels yalniz VIDEO okur.
ALTER TABLE post ADD COLUMN kind VARCHAR(8) NOT NULL DEFAULT 'PHOTO';
-- izlenme: kullanici basina gonderi basina tek sayim (Redis tekillestirme); tamamlanma = izlenme basina 0..100 yuzde toplami
ALTER TABLE post ADD COLUMN view_count INT NOT NULL DEFAULT 0;
ALTER TABLE post ADD COLUMN completion_pct_sum BIGINT NOT NULL DEFAULT 0;

-- Eski veri: ilk medyasi (position, id) VIDEO olan gonderiler VIDEO sayilir
UPDATE post SET kind = 'VIDEO'
WHERE id IN (
    SELECT m.post_id FROM post_media m
    WHERE m.post_id IS NOT NULL AND m.kind = 'VIDEO'
      AND NOT EXISTS (SELECT 1 FROM post_media m2 WHERE m2.post_id = m.post_id
                      AND (m2.position < m.position OR (m2.position = m.position AND m2.id < m.id)))
);

-- Reels sorgusu: yalniz VIDEO, rank_score DESC, id DESC (gorunur gonderiler)
CREATE INDEX pv_post_kind_rank_idx ON post (kind, rank_score DESC, id DESC) WHERE deleted_at IS NULL AND hidden_at IS NULL;

-- Kullanici populerlik puani: UserPopularityService saatlik gunceller (takipci + alinan begeni + gonderi sayisindan 0..100)
CREATE TABLE user_popularity (
    user_id        BIGINT      PRIMARY KEY REFERENCES app_user (id) ON DELETE CASCADE,
    score          SMALLINT    NOT NULL DEFAULT 0,
    follower_count INT         NOT NULL DEFAULT 0,
    likes_received BIGINT      NOT NULL DEFAULT 0,
    post_count     INT         NOT NULL DEFAULT 0,
    computed_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
