-- Sicak yol sorgularinin EXPLAIN (ANALYZE, BUFFERS) ciktisi. explain.sh calistirir.
-- Sorgular uygulamanin urettigi SQL'in (Hibernate/JDBC) elle yazilmis esdegeridir; sabitler demoperf verisine gore.
-- Her blok "@@ ad" satiriyla baslar. Sabit kullanici/konusma kimlikleri: kullanici 8, konusma 3 (okunmamis mesajli).

\echo @@ news_count_type
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM news_item ni WHERE ni.type = 'HABER' AND ni.hidden = false;
\echo @@ news_page_type
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM news_item ni WHERE ni.type = 'HABER' AND ni.hidden = false ORDER BY published_date DESC, id DESC OFFSET 400 LIMIT 20;
\echo @@ news_count_all
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM news_item ni WHERE ni.hidden = false;
\echo @@ news_page_all
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM news_item ni WHERE ni.hidden = false ORDER BY published_date DESC, id DESC OFFSET 400 LIMIT 20;
\echo @@ news_search_hits
EXPLAIN (ANALYZE, BUFFERS) SELECT n.id, n.title, n.summary FROM news_item n WHERE n.type = 'HABER' AND n.hidden = false AND (to_tsvector('turkish', n.title || ' ' || coalesce(n.summary, '')) @@ websearch_to_tsquery('turkish', 'sinav burs') OR n.title ILIKE '%sinav%') ORDER BY ts_rank(to_tsvector('turkish', n.title || ' ' || coalesce(n.summary, '')), websearch_to_tsquery('turkish', 'sinav burs')) DESC, n.published_date DESC, n.id DESC LIMIT 5;
\echo @@ news_search_page
EXPLAIN (ANALYZE, BUFFERS) SELECT n.* FROM news_item n WHERE n.hidden = FALSE AND (to_tsvector('turkish', n.title || ' ' || coalesce(n.summary, '')) @@ websearch_to_tsquery('turkish', 'sinav burs') OR n.title ILIKE '%sinav%') ORDER BY n.published_date DESC, n.id DESC LIMIT 20;
\echo @@ notif_page
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM notification n WHERE n.user_id = 13272 AND n.id < 100000000 ORDER BY n.id DESC LIMIT 21;
\echo @@ notif_unread_count
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM notification n WHERE n.user_id = 13272 AND n.read_at IS NULL;
\echo @@ conv_list
EXPLAIN (ANALYZE, BUFFERS) SELECT c.* FROM conversation c, conversation_member m WHERE m.conversation_id = c.id AND m.user_id = 8 AND m.left_at IS NULL AND c.last_message_id IS NOT NULL ORDER BY c.last_message_id DESC LIMIT 21;
\echo @@ msg_unread_counts
EXPLAIN (ANALYZE, BUFFERS) SELECT m.conversation_id, count(m.id) FROM message m, conversation_member cm WHERE cm.conversation_id = m.conversation_id AND cm.user_id = 8 AND m.conversation_id IN (3, 5, 7) AND m.id > cm.last_read_message_id AND m.sender_id <> 8 AND m.hidden_at IS NULL GROUP BY m.conversation_id;
\echo @@ msg_history
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM message m WHERE m.conversation_id = 3 AND m.created_at >= now() - interval '200 days' AND m.id < 499000 ORDER BY m.id DESC LIMIT 31;
\echo @@ event_search_ilike
EXPLAIN (ANALYZE, BUFFERS) SELECT e.* FROM user_event e WHERE e.status = 'ACTIVE' AND e.ends_at >= now() AND (e.title ILIKE '%etkinlik 12%' OR e.description ILIKE '%etkinlik 12%' OR e.location ILIKE '%etkinlik 12%') ORDER BY e.starts_at LIMIT 5;
\echo @@ community_search_ilike
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM community WHERE status = 'ACTIVE' AND visibility = 'PUBLIC' AND (name ILIKE '%c-12%' OR description ILIKE '%c-12%') ORDER BY id DESC LIMIT 5;
\echo @@ admin_users_list
EXPLAIN (ANALYZE, BUFFERS) SELECT id, email, display_name, created_at FROM app_user WHERE true ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 20 OFFSET 8000;
\echo @@ admin_users_q
EXPLAIN (ANALYZE, BUFFERS) SELECT id, email, display_name FROM app_user WHERE (display_name ILIKE '%Perf 123%' OR email ILIKE '%Perf 123%') ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 20;
\echo @@ admin_users_q_count
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM app_user WHERE (display_name ILIKE '%Perf 123%' OR email ILIKE '%Perf 123%');
\echo @@ admin_news_title_ilike
EXPLAIN (ANALYZE, BUFFERS) SELECT id, type, title FROM news_item WHERE title ILIKE '%sinav%' ORDER BY published_date DESC NULLS LAST, id DESC LIMIT 20 OFFSET 0;
\echo @@ report_messages_per_day
EXPLAIN (ANALYZE, BUFFERS) SELECT CAST(created_at AT TIME ZONE 'Europe/Istanbul' AS date) AS day, count(*) FROM message WHERE created_at >= now() - interval '30 days' AND created_at < now() AND hidden_at IS NULL GROUP BY 1;
\echo @@ report_messages_24h
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM message WHERE created_at >= now() - interval '24 hours';
\echo @@ report_rsvps_per_day
EXPLAIN (ANALYZE, BUFFERS) SELECT CAST(created_at AT TIME ZONE 'Europe/Istanbul' AS date) AS day, count(*) FROM event_rsvp WHERE created_at >= now() - interval '30 days' AND created_at < now() GROUP BY 1;
\echo @@ report_funnel_sent_message
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FILTER (WHERE EXISTS (SELECT 1 FROM message ms WHERE ms.sender_id = u.id)) FROM app_user u WHERE u.created_at >= now() - interval '120 days' AND u.status <> 'DELETED';
\echo @@ login_by_email
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM app_user WHERE email = 'demoperf.4242@bingol.edu.tr';
\echo @@ rsvp_by_user
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM event_rsvp WHERE user_id = 777 AND status = 'GOING';
\echo @@ member_of_communities
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM community_member WHERE user_id = 777 AND status = 'ACTIVE';
