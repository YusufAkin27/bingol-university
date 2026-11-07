-- Gonderi ayarlari (kullanici istegi 2026-11-07): begeni sayisini gizle + yorumlari kapat.
-- Mevcut gonderiler degismez (varsayilan FALSE); reels ayni tabloda oldugundan kapsanir.
ALTER TABLE post ADD COLUMN hide_like_count BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE post ADD COLUMN comments_disabled BOOLEAN NOT NULL DEFAULT FALSE;
