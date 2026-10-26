-- Etkinlik baslangic tarihi (kaynak detayindan; yoksa NULL), icerik yeniden deneme sayaci ve NULLS LAST indeksleri
ALTER TABLE news_item
    ADD COLUMN event_date           DATE,
    ADD COLUMN content_attempts     INT NOT NULL DEFAULT 0,
    ADD COLUMN content_attempted_at TIMESTAMPTZ;

CREATE INDEX idx_news170_type_hidden_date ON news_item (type, hidden, published_date DESC NULLS LAST, id DESC);
CREATE INDEX idx_news170_hidden_date ON news_item (hidden, published_date DESC NULLS LAST, id DESC);
CREATE INDEX idx_news170_event_date ON news_item (event_date) WHERE event_date IS NOT NULL;
CREATE INDEX idx_news170_content_retry ON news_item (content_attempted_at) WHERE content IS NULL;

-- Tarihi ayristirilamamis eski kayitlar: cekim gununu yayin tarihi say (siralamada sona dusmesinler)
UPDATE news_item SET published_date = (fetched_at AT TIME ZONE 'Europe/Istanbul')::date WHERE published_date IS NULL;
