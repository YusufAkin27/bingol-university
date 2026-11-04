-- No backfill: receipt cursors cannot reconstruct historical acknowledgement times.
ALTER TABLE message ADD COLUMN delivered_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE message ADD COLUMN read_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX msg_info_reply_idx ON message (reply_to_message_id, id DESC)
    WHERE reply_to_message_id IS NOT NULL;
