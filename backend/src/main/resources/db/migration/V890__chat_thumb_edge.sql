-- Sohbet gorseli kucuk resminin gercek uzun kenari (px). NULL = eski kayit (320 px). Istemci balonda
-- kucuk resmin yeterli olup olmadigina buna bakar; yetersizse ana gorseli (<=1600 px) kullanir.
ALTER TABLE message_attachment ADD COLUMN thumb_edge INTEGER;
