-- P13 yonetici mail altyapisi: bastirma kaydina not/kategori/ekleyen/maskeli adres; kuyruk arama indeksleri.
-- Adres yine DUZ saklanmaz (KVKK): yalniz maskeli gosterim (a***@alan) ve SHA-256 ozeti tutulur.
ALTER TABLE mail_suppression ADD COLUMN category VARCHAR(16) NOT NULL DEFAULT 'ANNOUNCEMENT';
ALTER TABLE mail_suppression ADD COLUMN note VARCHAR(300);
ALTER TABLE mail_suppression ADD COLUMN email_masked VARCHAR(120);
ALTER TABLE mail_suppression ADD COLUMN created_by BIGINT;
CREATE INDEX p13_supp_reason_created ON mail_suppression (reason, created_at DESC, id DESC);
-- Kuyruk listesi: alici (tam eslesme, kucuk harf) ve sablon/durum suzgeci
CREATE INDEX p13_outbox_rcpt_lower ON mail_outbox (lower(to_address), id DESC);
CREATE INDEX p13_outbox_tpl_status ON mail_outbox (template, status, id DESC);
