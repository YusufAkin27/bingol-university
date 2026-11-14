-- Akademisyen alani (V1900-V1905, onek ak1900_): akademisyen basvurusu/onayi. Rol eklenmez; app_user + bu satir.
CREATE TABLE academician (
    user_id       BIGINT       PRIMARY KEY REFERENCES app_user (id),
    title         VARCHAR(40)  NOT NULL,
    first_name    VARCHAR(60)  NOT NULL,
    last_name     VARCHAR(60)  NOT NULL,
    unit          VARCHAR(160),
    status        VARCHAR(16)  NOT NULL,
    approval_mode VARCHAR(8),
    reviewed_by   BIGINT       REFERENCES app_user (id),
    reviewed_at   TIMESTAMPTZ,
    reject_reason VARCHAR(300),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ak1900_academician_status_idx ON academician (status, created_at);
