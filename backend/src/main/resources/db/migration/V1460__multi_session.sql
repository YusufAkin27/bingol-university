-- MULTISESSION: cok oturum + "Cihazlarim". Indeks/kisit onekleri: usess_ (sema genelinde benzersiz).
-- Her giris (ve eski oturumun ilk yenilemesi) icin bir satir. Ham IP ve ham cihaz kimligi SAKLANMAZ:
-- ip_masked kismen maskelidir, device_hash ClientContexts HMAC-SHA256 ozetidir.
CREATE TABLE user_session (
    sid          VARCHAR(32)  PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    client       VARCHAR(8)   NOT NULL,
    platform     VARCHAR(16),
    device_name  VARCHAR(80),
    device_hash  VARCHAR(64),
    app_version  VARCHAR(32),
    ip_masked    VARCHAR(64),
    auth_time_ms BIGINT       NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at   TIMESTAMPTZ
);
-- Cihaz listesi (kullanicinin acik oturumlari, son kullanima gore) ve bilinen cihaz denetimi
CREATE INDEX usess_user_used_idx ON user_session (user_id, last_used_at DESC);
CREATE INDEX usess_user_hash_idx ON user_session (user_id, device_hash) WHERE device_hash IS NOT NULL;
-- Gece temizligi (revoked_at / last_used_at yasina gore)
CREATE INDEX usess_last_used_idx ON user_session (last_used_at);

-- FCM kaydi hangi oturumdan yapildi: belirli cihazdan cikista yalniz o cihazin push kaydi silinir.
ALTER TABLE device ADD COLUMN session_id VARCHAR(32);
CREATE INDEX usess_device_sid_idx ON device (session_id) WHERE session_id IS NOT NULL;
