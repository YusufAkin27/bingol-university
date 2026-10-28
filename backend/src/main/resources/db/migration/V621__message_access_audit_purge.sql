-- V621: message_access_audit saklama suresi dolunca silinebilsin (denetim L12: V68 tetikleyicisi her DELETE'i reddediyordu;
-- DbMaintenanceJob.longAudit 730 gunden eski satirlari silemiyor, saklama beyani (docs/legal/retention_*.md) gerceklesmiyordu).
-- Tetikleyici fonksiyonu degistirilir (V68 migration'i DEGISMEZ): UPDATE ve TRUNCATE yine her durumda reddedilir; DELETE yalnizca
-- 730 gunden eski satirlar icin serbesttir. Kayitlar saklama penceresi boyunca degistirilemez ve silinemez (yalniz eklenir).
CREATE OR REPLACE FUNCTION message_access_audit_immutable() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.created_at < now() - interval '730 days' THEN
            RETURN OLD;
        END IF;
    END IF;
    RAISE EXCEPTION 'message_access_audit is append-only (rows may be deleted only after 730 days)';
END;
$$ LANGUAGE plpgsql;
