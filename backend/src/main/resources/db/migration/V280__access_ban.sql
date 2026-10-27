-- V280: erisim engelleri (IP / CIDR / cihaz / kullanici), kullanici cihaz gunlugu, engellenen deneme gunlugu,
-- anonimlestirici (VPN/Tor/veri merkezi) aralik listesi. Cihaz kimligi yalnizca HMAC ozeti olarak saklanir.
CREATE TABLE access_ban (
    id           BIGSERIAL PRIMARY KEY,
    kind         VARCHAR(8)   NOT NULL,            -- IP | CIDR | DEVICE | USER
    ban_value    VARCHAR(80)  NOT NULL,            -- IP/CIDR metni, cihaz HMAC ozeti (hex) ya da kullanici id
    note         VARCHAR(300),
    reason_code  VARCHAR(16)  NOT NULL DEFAULT 'OTHER', -- ABUSE | SPAM | FRAUD | OTHER
    created_by   BIGINT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    hit_count    BIGINT       NOT NULL DEFAULT 0,
    last_hit_at  TIMESTAMPTZ
);
CREATE INDEX ban280_ban_active ON access_ban (active, kind);
CREATE INDEX ban280_ban_value ON access_ban (kind, ban_value);

CREATE TABLE user_device_log (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT       NOT NULL,
    device_hash   VARCHAR(64)  NOT NULL,           -- HMAC-SHA256 hex; cihaz basligi yoksa '-'
    platform      VARCHAR(8)   NOT NULL DEFAULT 'UNKNOWN',
    app_version   VARCHAR(32),
    ip            VARCHAR(45)  NOT NULL,
    ip_family     SMALLINT     NOT NULL,           -- 4 | 6
    first_seen_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_event    VARCHAR(10)  NOT NULL,           -- REGISTER | LOGIN | REFRESH | REQUEST
    seen_count    INTEGER      NOT NULL DEFAULT 1,
    CONSTRAINT ban280_udl_unique UNIQUE (user_id, device_hash, ip)
);
CREATE INDEX ban280_udl_device ON user_device_log (device_hash);
CREATE INDEX ban280_udl_ip ON user_device_log (ip);
CREATE INDEX ban280_udl_user_seen ON user_device_log (user_id, last_seen_at);
CREATE INDEX ban280_udl_seen ON user_device_log (last_seen_at);

CREATE TABLE blocked_attempt_log (
    id          BIGSERIAL PRIMARY KEY,
    ban_id      BIGINT,                            -- anonimlestirici engellerinde NULL
    kind        VARCHAR(12) NOT NULL,              -- IP | CIDR | DEVICE | USER | ANONYMIZER
    ip          VARCHAR(45),
    device_hash VARCHAR(64),
    user_id     BIGINT,
    path        VARCHAR(120),
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ban280_attempt_ban ON blocked_attempt_log (ban_id, id);
CREATE INDEX ban280_attempt_at ON blocked_attempt_log (attempted_at);

CREATE TABLE ban280_anonymizer_range (
    id       BIGSERIAL PRIMARY KEY,
    cidr     VARCHAR(50)  NOT NULL UNIQUE,
    source   VARCHAR(60),
    added_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
