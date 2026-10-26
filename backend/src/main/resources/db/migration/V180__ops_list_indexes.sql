-- ops: liste sorgulari icin eksik indeksler (engel listesi, yonetici destek kuyrugu)
CREATE INDEX ix_ops_user_block_blocker_created ON user_block (blocker_id, created_at DESC, blocked_id DESC);
CREATE INDEX ix_ops_ticket_queue ON support_ticket (status, id) WHERE email_verified;
