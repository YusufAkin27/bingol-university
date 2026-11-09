-- V1790: yonetici "tum sohbetler" gorunumu icin denetim kapsami ve suzgec ozeti (icerik DEGIL).
-- scope: NULL/USER/CONVERSATION/ALL; filters: sayfayi ureten suzgecin ozeti (tur, tarih, imlec...). Tablo yalnizca-ekleme
-- kalir (V68/V621 tetikleyicisi UPDATE/DELETE'i engeller); sutun eklemek tetikleyiciyi etkilemez.
ALTER TABLE message_access_audit ADD COLUMN scope   VARCHAR(12);
ALTER TABLE message_access_audit ADD COLUMN filters VARCHAR(400);
CREATE INDEX cf_maa_scope_created ON message_access_audit (scope, created_at DESC);
