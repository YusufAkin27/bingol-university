-- iOS Canli Etkinlik (ActivityKit) guncelleme jetonlari. YALNIZ kullanicinin kendi baslattigi surecler:
-- EVENT (katildigi etkinlik) ve EXAM (kendi girdigi sinav). Sohbet/arkadaslik/duyuru asla.
-- Jeton cihazda uretilir (Activity.pushTokenUpdates); suresi dolan/biten satirlar saatlik temizlenir.
CREATE TABLE IF NOT EXISTS live_activity (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT       NOT NULL,
    activity_id VARCHAR(64)  NOT NULL,
    kind        VARCHAR(8)   NOT NULL,
    ref_id      BIGINT       NOT NULL,
    push_token  VARCHAR(400),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ  NOT NULL,
    ended_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS la_user_activity_uq ON live_activity (user_id, activity_id);
CREATE INDEX IF NOT EXISTS la_ref_active_idx ON live_activity (kind, ref_id) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS la_expires_idx ON live_activity (expires_at);
