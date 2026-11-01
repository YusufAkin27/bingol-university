-- FIX-P05 (A05 capraz): kulup gonderilerinde yazara gore tarama (hesap silme/anonimlestirme, KVKK disa aktarim)
-- indekssizdi. Yalniz yeni indeks; veri degismez.
CREATE INDEX cnt1111_post_author_idx ON community_post (author_id);
