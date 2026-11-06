-- QA-P-07: POST /api/posts icin Idempotency-Key (zaman asimi sonrasi tekrar denemede ayni gonderi doner).
ALTER TABLE post ADD COLUMN idempotency_key VARCHAR(64);
CREATE UNIQUE INDEX uq_post_author_idem_key ON post (author_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
