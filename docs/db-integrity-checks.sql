-- BÜ Kampüs veri tutarlılığı: YALNIZ SELECT COUNT(*), kişisel veri göstermez. OTOMATİK ÇALIŞTIRILMAZ.
-- Canlıda çalıştırmadan önce sütun/tablo adlarını şemada doğrulayın; salt okunur kullanıcıyla çalıştırın.
-- poll.voter_count karşılaştırılmaz: hesap silmede oylar NULL'lanır, sayaç bilerek korunur.

-- 1) Gönderi beğeni sayacı sapması (like_boost hariç; gerçek sayaç)
SELECT COUNT(*) AS drift FROM post p
WHERE p.like_count <> (SELECT COUNT(*) FROM post_like l WHERE l.post_id = p.id);

-- 2) Takip sayaçları sapması
SELECT COUNT(*) AS drift FROM user_follow_stats s
WHERE s.follower_count <> (SELECT COUNT(*) FROM user_follow f WHERE f.followee_id = s.user_id)
   OR s.following_count <> (SELECT COUNT(*) FROM user_follow f WHERE f.follower_id = s.user_id);

-- 3) Forum yorum beğeni sayacı sapması
SELECT COUNT(*) AS drift FROM forum_comment c
WHERE c.like_count <> (SELECT COUNT(*) FROM forum_comment_like l WHERE l.comment_id = c.id);

-- 4) Forum anket seçenek oy sayacı sapması
SELECT COUNT(*) AS drift FROM forum_poll_option o
WHERE o.vote_count <> (SELECT COUNT(*) FROM forum_poll_vote v WHERE v.option_id = o.id);

-- 5) Negatif sayaçlar
SELECT 'post' AS tablo, COUNT(*) AS adet FROM post WHERE like_count < 0
UNION ALL SELECT 'poll_option', COUNT(*) FROM poll_option WHERE vote_count < 0
UNION ALL SELECT 'forum_comment', COUNT(*) FROM forum_comment WHERE like_count < 0 OR reply_count < 0;

-- 6) Yetim kayıtlar
SELECT COUNT(*) AS yetim_uye FROM conversation_member m LEFT JOIN conversation c ON c.id = m.conversation_id WHERE c.id IS NULL;
SELECT COUNT(*) AS yetim_forum_yorum FROM forum_comment c LEFT JOIN forum_topic t ON t.id = c.topic_id WHERE t.id IS NULL;

-- 7) Mesaj okundu imleci son mesajdan büyük olamaz
SELECT COUNT(*) AS bozuk_imlec FROM conversation_member m JOIN conversation c ON c.id = m.conversation_id
WHERE c.last_message_id IS NOT NULL AND m.last_read_message_id > c.last_message_id;

-- 8) Okunmamış bildirimlerde aynı collapse_key yinelemesi (V940 sonrası 0 beklenir)
SELECT COUNT(*) AS yinelenen FROM (
  SELECT user_id, collapse_key FROM notification
  WHERE read_at IS NULL AND collapse_key IS NOT NULL
  GROUP BY 1, 2 HAVING COUNT(*) > 1) x;
