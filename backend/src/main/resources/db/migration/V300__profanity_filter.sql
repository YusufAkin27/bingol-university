-- V300: uygunsuz ifade filtresi - yonetici ozel kelimeleri (BLOCK/ALLOW) ve engelleme istatistik gunlugu.
-- Yerlesik liste kaynak dosyalardadir (moderation/profanity-*.txt); burada yalnizca yonetici eklemeleri tutulur.
CREATE TABLE profanity_term (
    id              BIGSERIAL PRIMARY KEY,
    term            VARCHAR(80)  NOT NULL,           -- yoneticinin yazdigi (soz dizimi isaretleri dahil)
    term_normalized VARCHAR(100) NOT NULL,           -- sadelestirilmis tekil anahtar
    kind            VARCHAR(8)   NOT NULL,           -- BLOCK | ALLOW
    lang            VARCHAR(4)   NOT NULL DEFAULT 'ALL', -- TR | EN | AR | ALL (bilgi amacli)
    note            VARCHAR(200),
    created_by      BIGINT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT prf300_term_kind_chk CHECK (kind IN ('BLOCK', 'ALLOW'))
);
CREATE UNIQUE INDEX prf300_term_uq ON profanity_term (kind, term_normalized);

-- Engellenen deneme gunlugu: kelime SAKLANMAZ; yalnizca alan/varlik/kullanici. 90 gunden eski kayitlar silinir.
CREATE TABLE profanity_hit_log (
    id       BIGSERIAL PRIMARY KEY,
    field    VARCHAR(40) NOT NULL,
    entity   VARCHAR(24) NOT NULL,
    user_id  BIGINT,
    action   VARCHAR(8)  NOT NULL DEFAULT 'BLOCK',   -- BLOCK | FLAG
    at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX prf300_hit_at ON profanity_hit_log (at);
