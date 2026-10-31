-- W1-D: mesajlasma gizliligi. Indeks onekleri: msg9_.
-- T-025: gruba ekleyen kisi (cikan/cikarilan uyeyi ayni kisi yeniden ekleyemez) + yeniden ekleme yasagi kaydi.
ALTER TABLE conversation_member ADD COLUMN added_by BIGINT;

CREATE TABLE conversation_add_ban (
    user_id         BIGINT      NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    adder_id        BIGINT      NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    conversation_id BIGINT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, adder_id)
);
-- Ekleyen hesap silinince kayitlar PK'dan gider; ters yon (adder_id) icin
CREATE INDEX msg9_add_ban_adder ON conversation_add_ban (adder_id);

-- T-025: cevrimici/son gorulme gorunurlugu. Satiri olan herkes icin guvenli varsayilan; satiri olmayanlar
-- uygulamada SHARED_CONTEXT sayilir.
ALTER TABLE profile_privacy ADD COLUMN presence_audience VARCHAR(16) NOT NULL DEFAULT 'SHARED_CONTEXT';
ALTER TABLE profile_privacy ADD CONSTRAINT ck_pp_presence
    CHECK (presence_audience IN ('EVERYONE', 'SHARED_CONTEXT', 'ONLY_ME'));

-- T-033: tek gosterimlik acis iki asamali: satir acis basinda "talep" (delivered_at NULL), govde tamamen yazilinca
-- delivered_at dolar; yeniden acis penceresi icin reopened_at. Eski satirlar teslim edilmis sayilir.
ALTER TABLE message_attachment_view ADD COLUMN delivered_at TIMESTAMPTZ;
ALTER TABLE message_attachment_view ADD COLUMN reopened_at TIMESTAMPTZ;
UPDATE message_attachment_view SET delivered_at = viewed_at WHERE delivered_at IS NULL;
