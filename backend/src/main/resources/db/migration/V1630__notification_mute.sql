-- Kulup / etkinlik bazinda bildirim sessize alma (kullanici basina). Satir varsa o kaynak kaynakli kritik olmayan
-- bildirimler bu kullaniciya gitmez (uygulama ici kutu + push). Hesap silinince AccountDataPurger siler.
CREATE TABLE notification_mute (
    user_id     BIGINT      NOT NULL,
    target_type VARCHAR(12) NOT NULL,
    target_id   BIGINT      NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, target_type, target_id),
    CONSTRAINT nm_target_type_chk CHECK (target_type IN ('COMMUNITY', 'EVENT'))
);
CREATE INDEX nm_target_user_idx ON notification_mute (target_type, target_id, user_id);
