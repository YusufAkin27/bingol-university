-- Paket LD (20k kullanici yuk testi) bulgulari: arama sorgulari 2 vCPU'lu PostgreSQL'i doyuruyordu (docs/PERFORMANCE.md "Yuk testi").
-- (1) Haber/duyuru/etkinlik aramasi: ts_rank her eslesen satirda to_tsvector'u yeniden hesapliyordu -> SAKLI tsvector sutunu.
--     Ifade V30 idx_news_fts ile birebir ayni; sorgular artik n.search_vec kullanir (NewsRepository.VEC).
--     Not: ADD COLUMN ... GENERATED STORED tabloyu bir kez yeniden yazar (news_item kucuktur: on binlerce satir).
ALTER TABLE news_item
    ADD COLUMN search_vec tsvector GENERATED ALWAYS AS (to_tsvector('turkish', title || ' ' || coalesce(summary, ''))) STORED;
CREATE INDEX ld_news_search_vec ON news_item USING GIN (search_vec);

-- (2) Kesfet gonderi aramasi (PostSearchProvider): to_tsvector(p.body) OR p.body ILIKE '%q%' indekssizdi -> 30 bin gonderide
--     tam tarama ve istek basina ~1,1 sn CPU. Sorgudaki ifadelerle birebir ayni iki GIN indeksi (BitmapOr).
--     Buyuk tabloda uretimde CONCURRENTLY ile elle kurulabilir (Flyway islemi icinde gerekmez; post tablosu kucuk-orta).
CREATE INDEX ld_post_body_fts ON post USING GIN (to_tsvector('turkish', body));
CREATE INDEX ld_post_body_trgm ON post USING GIN (body gin_trgm_ops);
