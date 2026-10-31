-- W1-C / T-024: takip onerileri sorgusu (FollowService.suggestions) icin indeksler.
-- Aday havuzu "ayni bolum (+ sinif)" ve "kulup arkadaslarim"a daraltilir; bolum havuzu bu indeksle taranir.
-- Kismi indeks yalnizca onerilebilir hesaplari (ACTIVE + e-postasi dogrulanmis) kapsar: tablo kucuk ve yazimda ucuz.
-- Engel iliskisinin ters yonu (blocked_id -> blocker_id) yalniz dizin taramasiyla cevaplanir (idx_user_block_blocked
-- yalniz blocked_id idi; yeni indeks onu kapsar, eskisi surum disi birakilmadan korunur).

CREATE INDEX IF NOT EXISTS prv9_user_dept_class_idx
    ON app_user (department, class_year, id DESC)
    WHERE status = 'ACTIVE' AND email_verified = TRUE;

CREATE INDEX IF NOT EXISTS prv9_user_block_blocked_blocker_idx
    ON user_block (blocked_id, blocker_id);
