-- Kampus Forum aramasi (E alani): konu ve yorum icin SAKLI tsvector + GIN. A (V1400 forum_topic) ve B (V1410 forum_comment)
-- tablolarindan SONRA calisir (surum sirasi). Ifade V800 news_item.search_vec ile ayni kalip: to_tsvector('turkish', ..)
-- sabit regconfig ile IMMUTABLE oldugundan GENERATED STORED olabilir; uygulama sorgulari bu sutunu kullanir
-- (ts_rank her eslesen satirda tsvector'u yeniden hesaplamaz). Entity'lerde bu sutun YOKTUR (H2 testlerinde yok);
-- yalniz native SQL (PgForumSearchRepository) okur. Tablolar yeni ve kucuk (forum yeni acilir): yeniden yazim sorun degil.
-- pg_trgm V30'da kurulu; baslikta kisimsal kelime (ILIKE '%yem%') icin trigram GIN.
ALTER TABLE forum_topic
    ADD COLUMN search_vec tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('turkish', coalesce(title, '')), 'A') || setweight(to_tsvector('turkish', coalesce(body, '')), 'B')
    ) STORED;
CREATE INDEX fe14_topic_search_vec ON forum_topic USING GIN (search_vec);
CREATE INDEX fe14_topic_title_trgm ON forum_topic USING GIN (title gin_trgm_ops);

ALTER TABLE forum_comment
    ADD COLUMN search_vec tsvector GENERATED ALWAYS AS (to_tsvector('turkish', coalesce(body, ''))) STORED;
CREATE INDEX fe14_comment_search_vec ON forum_comment USING GIN (search_vec);
