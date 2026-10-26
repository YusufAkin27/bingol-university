-- T11: profil gizlilik ayarlari. Satir yoksa hepsi EVERYONE (mevcut davranis) sayilir.
CREATE TABLE profile_privacy (
    user_id               BIGINT      PRIMARY KEY REFERENCES app_user (id) ON DELETE CASCADE,
    avatar_audience       VARCHAR(16) NOT NULL DEFAULT 'EVERYONE',
    bio_audience          VARCHAR(16) NOT NULL DEFAULT 'EVERYONE',
    department_audience   VARCHAR(16) NOT NULL DEFAULT 'EVERYONE',
    faculty_audience      VARCHAR(16) NOT NULL DEFAULT 'EVERYONE',
    class_year_audience   VARCHAR(16) NOT NULL DEFAULT 'EVERYONE',
    -- Moderasyon (USER_AVATAR raporu) avatari gizledi: kullanici ayarindan bagimsiz, sahibi disinda kimse gormez
    avatar_hidden         BOOLEAN     NOT NULL DEFAULT FALSE,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_pp_avatar CHECK (avatar_audience IN ('EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME')),
    CONSTRAINT ck_pp_bio CHECK (bio_audience IN ('EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME')),
    CONSTRAINT ck_pp_dept CHECK (department_audience IN ('EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME')),
    CONSTRAINT ck_pp_faculty CHECK (faculty_audience IN ('EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME')),
    CONSTRAINT ck_pp_class CHECK (class_year_audience IN ('EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME'))
);
CREATE INDEX idx_pp_avatar_hidden ON profile_privacy (avatar_hidden) WHERE avatar_hidden;
