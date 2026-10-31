-- W1-E / T-035: sohbet bildirimi toplu yazimi (INSERT .. ON CONFLICT) icin kismi benzersiz indeks.
-- Ayni (user_id, collapse_key) icin tek OKUNMAMIS satir olabilir; okununca satir indeksten cikar ve yenisi acilabilir.
-- Eski kod "bul-sonra-yaz" ile eszamanli iki mesajda yinelenen satir uretebiliyordu: once temizlenir (en yeni kalir).

SET LOCAL statement_timeout = 0;

-- Yinelenenlerin sayaclarini en yeni satirda topla (rozet/"N yeni mesaj" bilgisi kaybolmasin)
UPDATE notification n
   SET group_count = s.total
  FROM (SELECT MAX(id) AS keep_id, SUM(group_count) AS total
          FROM notification
         WHERE read_at IS NULL AND collapse_key IS NOT NULL
         GROUP BY user_id, collapse_key
        HAVING COUNT(*) > 1) s
 WHERE n.id = s.keep_id;

-- Daha eski yinelenenleri sil
DELETE FROM notification n
 USING (SELECT id
          FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, collapse_key ORDER BY id DESC) AS rn
                  FROM notification
                 WHERE read_at IS NULL AND collapse_key IS NOT NULL) x
         WHERE x.rn > 1) d
 WHERE n.id = d.id;

CREATE UNIQUE INDEX fan9_notification_unread_collapse
    ON notification (user_id, collapse_key) WHERE read_at IS NULL;
