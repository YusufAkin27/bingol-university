-- Kulup onerisi hedef kitlesi: kulup hangi fakulte/bolumlere onerilsin (yalniz siralama, gorunurluk kisitlamaz).
-- value = katalogdaki kanonik (Turkce) fakulte/bolum adi (app_user.faculty / department ile ayni bicim).
CREATE TABLE community_audience (
    id           BIGSERIAL PRIMARY KEY,
    community_id BIGINT       NOT NULL REFERENCES community (id) ON DELETE CASCADE,
    kind         VARCHAR(12)  NOT NULL,
    value        VARCHAR(120) NOT NULL,
    CONSTRAINT uq_caud_target UNIQUE (community_id, kind, value)
);
CREATE INDEX idx_caud_kind_value ON community_audience (kind, value);
