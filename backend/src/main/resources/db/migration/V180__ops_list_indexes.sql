-- ops: engel listesi sorgusu (blocker'a gore, yeniden eskiye) icin indeks.
-- Yonetici destek kuyrugu zaten idx_ticket_admin (status, updated_at) ile karsilaniyor.
CREATE INDEX ix_ops_user_block_blocker_created ON user_block (blocker_id, created_at DESC, blocked_id DESC);
