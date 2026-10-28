-- V670: kulup derin yonetimi + kulup icerigi moderasyonu (P06/P10).
-- Gonderi/duyuru yonetici GIZLEMESI geri alinabilir: silinmeden (deleted) akistan kalkar, yonetici panelinde gorunur.
-- Yeni kolonlar NULL'a izinli; mevcut satirlar degismez. Indeks adlari p06_ onekli (tum semada benzersiz).

ALTER TABLE community_post ADD COLUMN hidden_at     TIMESTAMPTZ;
ALTER TABLE community_post ADD COLUMN hidden_reason VARCHAR(300);
ALTER TABLE community_post ADD COLUMN hidden_by     BIGINT;
ALTER TABLE community_post ADD COLUMN edited_at     TIMESTAMPTZ;

-- yonetici listesi: "gizlenenler" suzgeci (kismi: gizli olmayan satirlar girmez)
CREATE INDEX p06_post_hidden_idx ON community_post (hidden_at) WHERE hidden_at IS NOT NULL;
-- yonetici gonderi listesi: kulup + duyuru suzgeci, en yeni once
CREATE INDEX p06_post_comm_kind_idx ON community_post (community_id, announcement, id DESC);
-- uye listesi suzgeci: kulup + rol + durum
CREATE INDEX p06_member_role_idx ON community_member (community_id, role, status);
-- yonetici kulup listesi: durum + kategori suzgeci
CREATE INDEX p06_community_cat_idx ON community (category, status);
