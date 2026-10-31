-- T-026 / K-08: mesaj istegi (rizasiz DM ve grup daveti). request_state: ACCEPTED (varsayilan, mevcut tum uyelikler),
-- PENDING (alici kabul edene kadar listede yok, bildirim/push/WS/makbuz/presence yok), DECLINED (reddedildi, gizli).
ALTER TABLE conversation_member ADD COLUMN request_state VARCHAR(10) NOT NULL DEFAULT 'ACCEPTED';
ALTER TABLE conversation_member ADD CONSTRAINT dom9_ck_cm_request
    CHECK (request_state IN ('ACCEPTED', 'PENDING', 'DECLINED'));
CREATE INDEX dom9_cm_pending ON conversation_member (user_id) WHERE request_state <> 'ACCEPTED' AND left_at IS NULL;
