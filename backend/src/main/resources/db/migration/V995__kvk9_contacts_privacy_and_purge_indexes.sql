-- W2-F: KVKK / rehber eslestirme gizliligi. Indeks onekleri: kvk9_.
-- T-061: "Rehberden bulunabilirim" anahtari; varsayilan KAPALI (acik onay). Satiri olmayan kullanici da kapali sayilir.
ALTER TABLE profile_privacy ADD COLUMN contacts_discoverable BOOLEAN NOT NULL DEFAULT FALSE;

-- T-063: hesap silmede user_id ile satir silinen log tablolari tam taranmasin
CREATE INDEX kvk9_attempt_user ON blocked_attempt_log (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX kvk9_prf_hit_user ON profanity_hit_log (user_id) WHERE user_id IS NOT NULL;
