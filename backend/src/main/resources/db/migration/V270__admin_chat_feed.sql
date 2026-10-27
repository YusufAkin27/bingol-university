-- V270: yonetici toplu izleme alani (tum sohbet ek/mesaj akisi) icin imlecli sorgu indeksleri.
-- Mesaj akisi: tarih araligi + id imleci
CREATE INDEX adm270_message_created ON message (created_at, id);
-- Ek akisi: tarih araligi + id imleci (yalniz mesaja bagli ekler)
CREATE INDEX adm270_attachment_created ON message_attachment (created_at, id) WHERE message_id IS NOT NULL;
-- Tek gosterimlik ek suzgeci / sayaci
CREATE INDEX adm270_attachment_viewonce ON message_attachment (id) WHERE view_once;
-- Silinmis mesajlarin ekleri ve tur suzgeci icin tur + id
CREATE INDEX adm270_attachment_kind ON message_attachment (kind, id) WHERE message_id IS NOT NULL;
