-- V470: Kesfet "sade gonderi" karariyla kaldirilan ozelliklerin (yorum, hikaye, #etiket, @etiket, kaydet) verisi.
-- On ek: pdr470_. Yalniz guvenli DROP/DELETE; hicbir satir bu migration disinda kullanilmaz (kod kaldirildi).

-- 1) Kaldirilan icerik turlerine ait moderasyon kayitlari (ReportTargetType.STORY / FEED_COMMENT enum'dan kalkti;
--    kalirsa JPA satiri okurken IllegalArgumentException verir). Itirazlar once, sonra durum/ihlal/rapor.
DELETE FROM moderation_appeal      WHERE target_type IN ('STORY', 'FEED_COMMENT');
DELETE FROM moderation_strike      WHERE target_type IN ('STORY', 'FEED_COMMENT');
DELETE FROM moderation_target_state WHERE target_type IN ('STORY', 'FEED_COMMENT');
DELETE FROM report                 WHERE target_type IN ('STORY', 'FEED_COMMENT');

-- 2) Tablolar (alt tablolar once; indeksler tabloyla birlikte duser)
DROP TABLE IF EXISTS story_view;
DROP TABLE IF EXISTS story;
DROP TABLE IF EXISTS post_mention;
DROP TABLE IF EXISTS post_hashtag;
DROP TABLE IF EXISTS hashtag;
DROP TABLE IF EXISTS post_save;
DROP TABLE IF EXISTS post_comment;

-- 3) Kolonlar. Hikaye medyasi (story_id dolu, post_id bos) kolon dusunce "baglanmamis yukleme" olur ve
--    PostMediaJanitor tarafindan suresi gelince satir + baytlariyla temizlenir.
DROP INDEX IF EXISTS soc340_media_story_idx;
ALTER TABLE post_media DROP COLUMN IF EXISTS story_id;
ALTER TABLE post DROP COLUMN IF EXISTS comment_count;
