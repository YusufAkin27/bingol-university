-- Medya donusturme (ffmpeg) + gonderi videosu sifreleme (trn360_). Eklemeli: eski satirlar degismez
-- (transcode_status NULL, encrypted FALSE = duz, eski kayit; okuma geriye uyumludur).
ALTER TABLE post_media ADD COLUMN transcode_status   VARCHAR(12);
ALTER TABLE post_media ADD COLUMN wrapped_dek        VARCHAR(400);
ALTER TABLE post_media ADD COLUMN encrypted          BOOLEAN     NOT NULL DEFAULT FALSE;
ALTER TABLE post_media ADD COLUMN transcode_attempts SMALLINT    NOT NULL DEFAULT 0;
ALTER TABLE post_media ADD COLUMN transcode_at       TIMESTAMPTZ;

-- Isleyici yalnizca kuyruktakileri tarar
CREATE INDEX trn360_post_media_queue_idx ON post_media (id)
    WHERE transcode_status IN ('PENDING', 'PROCESSING');
-- Eski duz videolari sifreleme gocmen isi
CREATE INDEX trn360_post_media_plain_video_idx ON post_media (id)
    WHERE kind = 'VIDEO' AND encrypted = FALSE;

-- Sohbet eklerinde ayni durum alani (sohbet videosu konusma DEK'iyle zaten sifreli; donusturme sirasi icin)
ALTER TABLE message_attachment ADD COLUMN transcode_status VARCHAR(12);
