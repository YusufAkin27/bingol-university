-- Veri butunlugu denetimi (yuk/yaris testlerinden sonra). Her satir "ihlal sayisi": 0 olmalidir.
-- Kullanim: psql -U bingol -d bingol -f integrity.sql
\pset format aligned
SELECT 'kapasite yarisi: going_count > capacity' AS kontrol, count(*) AS ihlal
FROM user_event WHERE capacity IS NOT NULL AND going_count > capacity;
SELECT 'kapasite yarisi: GOING RSVP sayisi != going_count (tum ldx etkinlikleri)' AS kontrol, count(*) AS ihlal
FROM user_event e WHERE e.title LIKE 'ldx %'
  AND e.going_count <> (SELECT count(*) FROM event_rsvp r WHERE r.event_id = e.id AND r.status = 'GOING');
SELECT 'kapasite yarisi etkinligi: dolu koltuk / kapasite' AS kontrol, going_count || '/' || capacity AS ihlal
FROM user_event WHERE title = 'ldx Kapasite Yarisi';
SELECT 'anket: voter_count != ballot sayisi' AS kontrol, count(*) AS ihlal
FROM poll p WHERE p.title LIKE 'ldx %' AND p.voter_count <> (SELECT count(*) FROM poll_ballot b WHERE b.poll_id = p.id);
SELECT 'anket: secenek oy toplami != poll_vote satiri (SINGLE)' AS kontrol, count(*) AS ihlal
FROM poll p WHERE p.title LIKE 'ldx %' AND p.type = 'SINGLE'
  AND (SELECT coalesce(sum(o.vote_count), 0) FROM poll_option o WHERE o.poll_id = p.id) <> (SELECT count(*) FROM poll_vote v WHERE v.poll_id = p.id);
SELECT 'anket: ayni kullanici ayni ankette birden fazla ballot' AS kontrol, count(*) AS ihlal
FROM (SELECT poll_id, user_id FROM poll_ballot GROUP BY 1, 2 HAVING count(*) > 1) x;
SELECT 'anket: ayni kullanici ayni ankette (SINGLE) birden fazla oy satiri' AS kontrol, count(*) AS ihlal
FROM (SELECT v.poll_id, v.user_id FROM poll_vote v JOIN poll p ON p.id = v.poll_id WHERE p.type = 'SINGLE' GROUP BY 1, 2 HAVING count(*) > 1) x;
SELECT 'begeni: like_count != post_like satiri' AS kontrol, count(*) AS ihlal
FROM post p WHERE p.body LIKE 'ldx %' AND p.like_count <> (SELECT count(*) FROM post_like l WHERE l.post_id = p.id);
SELECT 'takip: follower_count != user_follow satiri' AS kontrol, count(*) AS ihlal
FROM user_follow_stats s WHERE s.follower_count <> (SELECT count(*) FROM user_follow f WHERE f.followee_id = s.user_id);
SELECT 'takip: following_count != user_follow satiri' AS kontrol, count(*) AS ihlal
FROM user_follow_stats s WHERE s.following_count <> (SELECT count(*) FROM user_follow f WHERE f.follower_id = s.user_id);
SELECT 'mesaj: ayni (konusma, gonderen, client_id) tekrar' AS kontrol, count(*) AS ihlal
FROM (SELECT conversation_id, sender_id, client_id FROM message WHERE client_id IS NOT NULL GROUP BY 1, 2, 3 HAVING count(*) > 1) x;
SELECT 'mesaj: konusma last_message_id geride (yuk testi mesajlari)' AS kontrol, count(*) AS ihlal
FROM conversation c WHERE c.last_message_id < (SELECT max(m.id) FROM message m WHERE m.conversation_id = c.id) AND c.id IN (SELECT conversation_id FROM message WHERE client_id LIKE 'ws-%' OR body_ciphertext IS NOT NULL);
