-- V630: denetim kaydi v2 (P02). admin_audit'e hedef varlik, SEBEP, ozet ve istek kimligi eklenir.
-- Mevcut satirlar degismez (yeni kolonlar NULL'a izinli). Govde SAKLANMAZ: yalniz `reason` alani ve kisa `summary`.
-- Saklama: V520 ayari ayni (365 gun, dbmaint.DbMaintenanceJob created_at'e gore siler); yeni kolon retention'i etkilemez.
-- Indeks adlari onekli (adm630_) ve tum semada benzersizdir.

ALTER TABLE admin_audit ADD COLUMN target_type VARCHAR(32);
ALTER TABLE admin_audit ADD COLUMN target_id   VARCHAR(64);
ALTER TABLE admin_audit ADD COLUMN reason      VARCHAR(300);
ALTER TABLE admin_audit ADD COLUMN summary     VARCHAR(500);
ALTER TABLE admin_audit ADD COLUMN request_id  VARCHAR(64);

-- "bu kullanici/kayit uzerinde kim ne yapti" sorgusu (kismi: hedefsiz eski satirlar girmez)
CREATE INDEX adm630_audit_target ON admin_audit (target_type, target_id, created_at DESC) WHERE target_type IS NOT NULL;
-- durum + zaman suzgeci (hatali/yetkisiz denemeleri bulma)
CREATE INDEX adm630_audit_status_created ON admin_audit (status, created_at DESC);

-- Yonetici sohbet erisim kaydi listesi: tur + zaman ve hedef kullanici suzgeci (idx adm96_audit_target zaten var)
CREATE INDEX adm630_maa_kind_created ON message_access_audit (kind, created_at DESC);
