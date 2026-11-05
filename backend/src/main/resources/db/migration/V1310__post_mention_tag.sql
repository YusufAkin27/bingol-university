-- V1310: gonderi etiketleme (mention). Yazar yalniz TAKIP ETTIGI kisileri etiketler; en cok 10 kisi / gonderi.
-- Eski post_mention tablosu (V340) V470 ile dusurulmustu; bu, yeni ve sade sema: yalniz etiket (hashtag/yorum yok).
-- Yalniz ekleme: eski imaj yeni semayla da acilir. Gonderi silinince (kalici) satirlar duser; yumusak silmede hesap
-- silme akisi (PostAccountPurger) yazarin gonderilerindeki etiketleri siler.
CREATE TABLE post_mention (
    post_id    BIGINT      NOT NULL REFERENCES post (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES app_user (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);
CREATE INDEX pm1310_user_time_idx ON post_mention (user_id, created_at DESC);
