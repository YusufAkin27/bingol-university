-- Sohbet sesli mesaji (V1): ek turune AUDIO eklenir (m4a/AAC, sunucuda ftyp + sure dogrulamasi).
ALTER TABLE message_attachment DROP CONSTRAINT vid230_att_kind_ck;
ALTER TABLE message_attachment ADD CONSTRAINT vcm1820_att_kind_ck CHECK (kind IN ('IMAGE', 'VIDEO', 'AUDIO'));
