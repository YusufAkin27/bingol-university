-- V710: yonetici sohbet mudahalesi (P08). Hepsi NULL'a izinli yeni kolonlar; mevcut satirlar degismez.
-- Indeks adlari p08_ onekli ve tum semada benzersizdir.

-- Yonetici gizlemesi: mesaj icerigi SILINMEZ, kullanici API'si "yonetici tarafindan kaldirildi" yer tutucusu doner.
-- hidden_at de birlikte yazilir (var olan tum gizli-mesaj sorgulari/kontrolleri aynen calisir); admin_hidden_at bu gizlemenin
-- moderasyon gizlemesinden AYRI ve geri alinabilir oldugunu isaretler.
ALTER TABLE message ADD COLUMN admin_hidden_at TIMESTAMPTZ;
ALTER TABLE message ADD COLUMN admin_hidden_by BIGINT REFERENCES app_user (id);
-- Kalici silme: sifreli govde/duzenleme gecmisi/tepki/ek temizlenir, satir (yer tutucu) kalir; geri alinamaz.
ALTER TABLE message ADD COLUMN purged_at TIMESTAMPTZ;

-- Sohbet kapatma: yeni mesaj gonderimini kapatir (uyelikler ve gecmis korunur).
ALTER TABLE conversation ADD COLUMN closed_at     TIMESTAMPTZ;
ALTER TABLE conversation ADD COLUMN closed_by     BIGINT REFERENCES app_user (id);
ALTER TABLE conversation ADD COLUMN closed_reason VARCHAR(300);

CREATE INDEX p08_message_admin_hidden ON message (conversation_id) WHERE admin_hidden_at IS NOT NULL;
CREATE INDEX p08_conversation_closed ON conversation (closed_at) WHERE closed_at IS NOT NULL;
