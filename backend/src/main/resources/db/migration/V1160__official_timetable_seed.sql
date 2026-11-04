-- V1160: resmi ders programinin ogrencinin kisisel programina tohumlandigi isareti. Onek: tts_
-- (kullanici, donem) basina en cok bir satir: satir varsa ayni donem icin otomatik tohumlama bir daha yapilmaz
-- (ogrenci dersleri silse bile). Eszamanli iki istekte birincil anahtar ikinci eklemeyi reddeder.
CREATE TABLE tt_official_seed (
    user_id   BIGINT       NOT NULL REFERENCES app_user (id),
    term      VARCHAR(40)  NOT NULL,
    unit      VARCHAR(160),
    seeded_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT tts_official_seed_pk PRIMARY KEY (user_id, term)
);
