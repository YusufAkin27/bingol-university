-- Bildirim tasarimi (Stitch) arka ucu:
--  (1) "Bugunun menusu" gunluk bildirimi KENDI bayragiyla ve varsayilan KAPALI (kullanici acar; her gun push istenmeyen
--      bir bildirimdir). Mevcut satirlar da FALSE alir.
--  (2) Birim duyurusu bildirimi gece cekimi yerine sabah toplu gider: gonderilmis kaydi `notified_at` ile isaretleriz.
--      Mevcut tum kayitlar gonderilmis sayilir (yayindan sonra gecmis duyurular icin bildirim yagmuru olmasin).
ALTER TABLE notification_pref ADD COLUMN menu_daily BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE unit_announcement ADD COLUMN notified_at TIMESTAMPTZ;
UPDATE unit_announcement SET notified_at = now() WHERE notified_at IS NULL;
CREATE INDEX ntf_unit_ann_pending_idx ON unit_announcement (id) WHERE notified_at IS NULL;
