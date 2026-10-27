-- Tek gosterimlik gorsel + grup fotografi.
-- view_once: ek yalnizca alicilarca bir kez acilir; purged_at: baytlar diskten silindi (goruntuleme kaydi kalir).
ALTER TABLE message_attachment ADD COLUMN view_once BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE message_attachment ADD COLUMN purged_at TIMESTAMPTZ;

CREATE TABLE message_attachment_view (
    attachment_id BIGINT      NOT NULL REFERENCES message_attachment (id) ON DELETE CASCADE,
    user_id       BIGINT      NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    viewed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (attachment_id, user_id)
);
CREATE INDEX vo210_view_user ON message_attachment_view (user_id);
-- Zamanli temizlik: suresi dolmamis (bayti silinmemis) tek gosterimlikleri tarar
CREATE INDEX vo210_att_viewonce ON message_attachment (created_at) WHERE view_once AND purged_at IS NULL;

-- Grup fotografi (herkese acik avatar hattindan; /files/avatars/...)
ALTER TABLE conversation ADD COLUMN avatar_url VARCHAR(300);
