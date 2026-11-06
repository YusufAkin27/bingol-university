-- Etkinlik yoklamasi acma anahtari + etkinlik moderatorleri (sahip, kulup uyelerinden secer; yetkiler bit alani).
ALTER TABLE user_event ADD COLUMN attendance_open BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE event_moderator (
    id          BIGSERIAL PRIMARY KEY,
    event_id    BIGINT NOT NULL REFERENCES user_event (id) ON DELETE CASCADE,
    user_id     BIGINT NOT NULL,
    permissions INT NOT NULL DEFAULT 0,
    added_by    BIGINT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_evmod_event_user UNIQUE (event_id, user_id)
);
CREATE INDEX idx_evmod_user ON event_moderator (user_id);
