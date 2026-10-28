-- Kuyruk onceligi: 0 = islemsel (kod, guvenlik), 1 = duyuru (hiz siniri ve bastirma listesine tabi).
ALTER TABLE mail_outbox ADD COLUMN priority INT NOT NULL DEFAULT 0;
CREATE INDEX mls420_outbox_prio_due ON mail_outbox (priority, next_attempt_at, id) WHERE status IN ('PENDING', 'FAILED');
-- Hiz siniri ve ayni aliciya tekrar siniri sorgulari
CREATE INDEX mls420_outbox_sent ON mail_outbox (priority, sent_at) WHERE status = 'SENT';
CREATE INDEX mls420_outbox_rcpt ON mail_outbox (to_address, sent_at) WHERE status = 'SENT';
