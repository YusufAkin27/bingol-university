\set ON_ERROR_STOP 1
INSERT INTO app_user (email, password_hash, display_name, email_verified, status, role, language, created_at)
SELECT 'u'||i||'@bingol.edu.tr','x', n, TRUE, 'ACTIVE','USER','tr', now()
FROM (VALUES (1,'Şirin Yıldız'),(2,'ŞİRİN YILDIRIM'),(3,'Ayşe Yıldızhan'),(4,'Çağla Öztürk'),(5,'IŞIK Gökçe'),(6,'Ismail Çelik'),(7,'İsmail Çelik'),(8,'Sirinn Askıda')) v(i,n);
UPDATE app_user SET status='SUSPENDED' WHERE email='u8@bingol.edu.tr';
\echo '--- search sirin yil'
SELECT u.id, u.display_name FROM app_user u WHERE u.status = 'ACTIVE' AND u.email_verified = TRUE AND u.deleted_at IS NULL AND u.id NOT IN (-1)
 AND lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE concat('%', 'sirin', '%') ESCAPE '\'
 AND lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE concat('%', 'yil', '%') ESCAPE '\'
 AND lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE concat('%', '', '%') ESCAPE '\'
ORDER BY CASE WHEN lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) = 'sirin yil' THEN 0
 WHEN lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE concat('sirin yil', '%') ESCAPE '\' THEN 1
 WHEN concat(' ', lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu'))) LIKE concat('% ', 'sirin yil', '%') ESCAPE '\' THEN 2 ELSE 3 END,
 lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')), u.id LIMIT 21 OFFSET 0;
\echo '--- search ismail (I/i dotted)'
SELECT u.id, u.display_name FROM app_user u WHERE lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE '%ismail%';
\echo '--- search isik'
SELECT u.id, u.display_name FROM app_user u WHERE lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE '%isik%';
\echo '--- index used?'
SET enable_seqscan = off;
EXPLAIN SELECT u.id FROM app_user u WHERE lower(translate(u.display_name, 'İIıŞşĞğÜüÖöÇçÂâÎîÛû', 'iiissgguuooccaaiiuu')) LIKE '%yil%';
RESET enable_seqscan;
\echo '--- comment counters SQL'
INSERT INTO post (author_id, body, media_count) VALUES (1,'p1',1);
INSERT INTO post_media (post_id, owner_id, kind, storage_key, content_type, bytes, duration_ms, thumb_key) VALUES (1,1,'VIDEO','k','video/mp4',10, 12000, 'tk');
INSERT INTO post_comment (post_id, author_id, body) VALUES (1,2,'c1');
INSERT INTO post_comment (post_id, parent_id, reply_to_id, author_id, body) VALUES (1,1,1,3,'r1');
INSERT INTO post_comment (post_id, parent_id, reply_to_id, author_id, body, hidden_at) VALUES (1,1,1,4,'r2 hidden', now());
UPDATE post_comment AS c SET reply_count = (SELECT COUNT(*) FROM post_comment r WHERE r.parent_id = c.id AND r.deleted_at IS NULL AND r.hidden_at IS NULL) WHERE c.parent_id IS NULL AND c.post_id IN (1);
UPDATE post AS p SET comment_count = (SELECT COUNT(*) FROM post_comment c WHERE c.post_id = p.id AND c.deleted_at IS NULL AND c.hidden_at IS NULL AND (c.parent_id IS NULL OR EXISTS (SELECT 1 FROM post_comment pc WHERE pc.id = c.parent_id AND pc.deleted_at IS NULL AND pc.hidden_at IS NULL))) WHERE p.id IN (1);
SELECT p.comment_count, (SELECT reply_count FROM post_comment WHERE id=1) AS replies FROM post p WHERE id=1;
UPDATE post SET comment_count = 99 WHERE id = 1;
UPDATE post AS p SET comment_count = (SELECT COUNT(*) FROM post_comment c WHERE c.post_id = p.id AND c.deleted_at IS NULL AND c.hidden_at IS NULL AND (c.parent_id IS NULL OR EXISTS (SELECT 1 FROM post_comment pc WHERE pc.id = c.parent_id AND pc.deleted_at IS NULL AND pc.hidden_at IS NULL))) WHERE p.comment_count <> (SELECT COUNT(*) FROM post_comment c WHERE c.post_id = p.id AND c.deleted_at IS NULL AND c.hidden_at IS NULL AND (c.parent_id IS NULL OR EXISTS (SELECT 1 FROM post_comment pc WHERE pc.id = c.parent_id AND pc.deleted_at IS NULL AND pc.hidden_at IS NULL)));
SELECT comment_count FROM post WHERE id=1;
\echo '--- reels search'
SELECT p.id, p.body, u.display_name, vm.id AS media_id, vm.duration_ms, vm.thumb_key
FROM post p JOIN app_user u ON u.id = p.author_id
JOIN LATERAL (SELECT m.id, m.duration_ms, m.thumb_key FROM post_media m WHERE m.post_id = p.id AND m.kind = 'VIDEO' AND m.hidden_at IS NULL ORDER BY m.position, m.id LIMIT 1) vm ON TRUE
WHERE p.deleted_at IS NULL AND p.hidden_at IS NULL AND u.deleted_at IS NULL AND u.status = 'ACTIVE' AND p.body IS NOT NULL
AND (to_tsvector('turkish', p.body) @@ websearch_to_tsquery('turkish', 'p1') OR p.body ILIKE '%p1%')
ORDER BY ts_rank(to_tsvector('turkish', p.body), websearch_to_tsquery('turkish', 'p1')) DESC, p.id DESC LIMIT 11 OFFSET 0;
