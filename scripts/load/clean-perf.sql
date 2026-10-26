-- seed-perf.sql ile eklenen her seyi siler (yalnizca "demoperf" onekli kayitlar). Bagli satirlar CASCADE ile gider.
BEGIN;
DELETE FROM conversation WHERE created_by IN (SELECT id FROM app_user WHERE email LIKE 'demoperf.%@bingol.edu.tr');
DELETE FROM user_event WHERE created_by IN (SELECT id FROM app_user WHERE email LIKE 'demoperf.%@bingol.edu.tr');
DELETE FROM community WHERE owner_id IN (SELECT id FROM app_user WHERE email LIKE 'demoperf.%@bingol.edu.tr');
DELETE FROM news_item WHERE url LIKE 'https://demoperf.invalid/%';
DELETE FROM app_user WHERE email LIKE 'demoperf.%@bingol.edu.tr';
COMMIT;
