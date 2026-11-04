-- V1221: Reels izleme gecmisi (kullanici bazli, 45 gun saklama: PostWatchRetentionJob) + "ilgilenmiyorum".
-- Kisisel veri minimal: yalniz kimlikler, sayaclar, zamanlar; hesap silinince silinir, KVKK disa aktarima girer.
CREATE TABLE post_watch (
    user_id        BIGINT      NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    post_id        BIGINT      NOT NULL REFERENCES post (id) ON DELETE CASCADE,
    first_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    impressions    INT         NOT NULL DEFAULT 0,
    watch_ms       BIGINT      NOT NULL DEFAULT 0,
    completion_pct SMALLINT    NOT NULL DEFAULT 0,
    skips          INT         NOT NULL DEFAULT 0,
    not_interested BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, post_id)
);
-- saklama taramasi ve kullanicinin son gorulenleri
CREATE INDEX pv_post_watch_seen_idx ON post_watch (last_seen_at);
CREATE INDEX pv_post_watch_user_seen_idx ON post_watch (user_id, last_seen_at DESC);
-- gonderi silinince (ON DELETE CASCADE) tam tarama olmasin
CREATE INDEX pv_post_watch_post_idx ON post_watch (post_id);
