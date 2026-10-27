-- Kulup silme (yumusak, DELETED) ve etkinlik kayit kapatma (registration_closed).
ALTER TABLE community DROP CONSTRAINT ck_community_status;
ALTER TABLE community ADD CONSTRAINT ck_community_status
    CHECK (status IN ('PENDING_REVIEW', 'ACTIVE', 'REJECTED', 'HIDDEN', 'DELETED'));

ALTER TABLE user_event ADD COLUMN registration_closed BOOLEAN NOT NULL DEFAULT FALSE;

-- Etkinliklerim "created/past" modlari icin: olusturan + bitis sirasi.
CREATE INDEX idx_uev_creator_ends ON user_event (created_by, ends_at DESC);
