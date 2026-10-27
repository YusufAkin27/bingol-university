-- "Sohbeti sil" (yalniz cagiran icin): imlec + listeden gizleme. Karsi taraf ve mesajlar degismez.
ALTER TABLE conversation_member ADD COLUMN cleared_up_to_message_id BIGINT NOT NULL DEFAULT 0;
ALTER TABLE conversation_member ADD COLUMN hidden_at TIMESTAMPTZ;
-- Liste sorgusu gizlileri eler; gizli satirlar azdir, kismi indeks yeterli
CREATE INDEX clr231_member_hidden ON conversation_member (user_id) WHERE hidden_at IS NOT NULL;
