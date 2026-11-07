-- V1600 (Kampus Forum): baslangic tartisma konulari + yorumlar + begeniler (kullanici istegi: forum bos gorunmesin).
-- Mevcut AKTIF ve e-postasi dogrulanmis ilk kullanicilar (id sirasiyla, en cok 10) konu/yorum/begeni yazarlari olarak atanir;
-- ham SQL oldugundan bildirim/push GONDERILMEZ. Sayaclar eklenen satirlardan hesaplanir (uydurma sayi yok).
-- Idempotent: idem_key 'seed-v1600-%' olan konu varsa hicbir sey yapmaz. 3'ten az aktif kullanici varsa atlar.
-- Silmek icin: DELETE ... WHERE idem_key LIKE 'seed-v1600-%' (yorum/begeni/takma ad satirlari konuya bagli temizlenir).

DO $seed$
DECLARE
    uids BIGINT[];
    n INT;
    t RECORD;
    c RECORD;
    tid BIGINT;
    cid BIGINT;
    cat BIGINT;
    author BIGINT;
    commenter BIGINT;
    liker BIGINT;
    ts TIMESTAMPTZ;
    k INT;
    idx INT;
    first_cid BIGINT;
BEGIN
    IF EXISTS (SELECT 1 FROM forum_topic WHERE idem_key LIKE 'seed-v1600-%') THEN
        RETURN;
    END IF;
    SELECT array_agg(id ORDER BY id) INTO uids
      FROM (SELECT id FROM app_user WHERE status = 'ACTIVE' AND email_verified ORDER BY id LIMIT 10) u;
    n := COALESCE(cardinality(uids), 0);
    IF n < 3 THEN
        RETURN;
    END IF;

    FOR t IN
        SELECT * FROM (VALUES
            (1,  'gundem',        FALSE, 'Bu hafta sonu Bingölde hava nasıl olacak, planı olan var mı?',
                 'Hafta sonu için dışarı çıkmayı düşünüyorum ama hava durumu belirsiz. Planı olan ya da gezi önerisi olan var mı? Birlikte bir şeyler yapabiliriz.'),
            (2,  'yemekhane',     FALSE, 'Yemekhane menüsünde en sevdiğiniz yemek hangisi?',
                 'Bu ay menüye bakınca bazı günler gerçekten güzel görünüyor. Sizin için yemekhanenin en iyi yemeği hangisi, hangi günü kaçırmıyorsunuz?'),
            (3,  'dersler',       FALSE, 'Final haftası için ders çalışma düzeni önerileri',
                 'Finaller yaklaşırken düzenli çalışmakta zorlanıyorum. Pomodoro, grup çalışması, sabah erken kalkmak... Sizde en iyi işe yarayan yöntem hangisi?'),
            (4,  'kampus-yasami', TRUE,  'Kampüste sessiz çalışma yapılacak en iyi köşeler',
                 'Kütüphane bazen çok kalabalık oluyor. Kampüste sessiz ve rahat ders çalışılabilecek başka yerler biliyor musunuz?'),
            (5,  'yurtlar',       FALSE, 'Yurtta yeni başlayanlara tavsiyeler',
                 'Bu dönem yurda yeni yerleşenler için aklınızda kalan tavsiyeler neler? Oda düzeni, çamaşırhane saatleri, komşuluk gibi küçük ama işe yarar şeyler.'),
            (6,  'etkinlikler',   FALSE, 'Hangi kulüp etkinliğine katıldınız, tavsiye eder misiniz?',
                 'Yeni dönemde bir kulübe katılmak istiyorum. Katıldığınız etkinliklerden hangisi size en çok şey kattı?'),
            (7,  'serbest-kursu', FALSE, 'Son okuduğunuz kitap ne, öneriniz var mı?',
                 'Ders dışında kitap okumaya zaman bulabilenler: son okuduğunuz ve başkalarına önerebileceğiniz bir kitap var mı?'),
            (8,  'oneri-sikayet', FALSE, 'Kampüs içi ulaşım saatleri için öneri',
                 'Akşam geç saatlerde kampüsten şehir merkezine dönüş zor oluyor. Servis saatlerine ek sefer eklenmesi konusunda ne düşünüyorsunuz?'),
            (9,  'serbest-kursu', FALSE, 'Bu aralar hangi dizi ya da filmi izliyorsunuz?',
                 'Sınav arasında kafa dinlemek için izlenebilecek bir şeyler arıyorum. Son izlediğiniz ve beğendiğiniz yapımlar neler?'),
            (10, 'serbest-kursu', TRUE,  'Telefon kullanımını nasıl azalttınız?',
                 'Ekran süresi günde 6 saati geçti. Telefonu bırakıp daha verimli zaman geçirmek için denediğiniz işe yarar bir yöntem var mı?'),
            (11, 'gundem',        FALSE, 'Staj için CV hazırlarken nelere dikkat ediyorsunuz?',
                 'Yaz stajı başvuruları için CV hazırlıyorum. Tek sayfa mı olmalı, proje ve kulüp deneyimleri nasıl yazılmalı? Tecrübelerinizi paylaşır mısınız?'),
            (12, 'kampus-yasami', FALSE, 'Bingölde gezilecek yerler: misafir gelince nereye götürürsünüz?',
                 'Dışarıdan arkadaşlarım ziyarete gelecek. Bingölde mutlaka göstermeniz gereken yerler ve yemek önerileri neler?'),
            (13, 'serbest-kursu', FALSE, 'Spor alışkanlığı edinmek için ipuçları',
                 'Başlayıp bırakıyorum. Düzenli spor yapmayı sürdürebilenler nasıl başardınız? Kampüste kullanabileceğimiz alanlar için de önerilere açığım.'),
            (14, 'gundem',        FALSE, 'Yapay zekâ araçlarını ders çalışırken nasıl kullanıyorsunuz?',
                 'Konu özeti çıkarmak, soru çözmek ya da fikir üretmek için kullanan var mı? Nerede işe yarıyor, nerede dikkat etmek gerekiyor?')
        ) v(ix, slug, anon, title, body)
        ORDER BY ix
    LOOP
        SELECT id INTO cat FROM forum_category WHERE slug = t.slug;
        IF cat IS NULL THEN
            CONTINUE;
        END IF;
        author := uids[1 + (t.ix * 3) % n];
        ts := now() - ((15 - t.ix) * interval '8 hours') - interval '20 minutes';

        INSERT INTO forum_topic (user_id, category_id, title, body, anonymous, idem_key, created_at, updated_at, last_activity_at)
        VALUES (author, cat, t.title, t.body, t.anon, 'seed-v1600-' || t.ix, ts, ts, ts)
        RETURNING id INTO tid;
        IF t.anon THEN
            INSERT INTO forum_anon_alias (topic_id, user_id, n) VALUES (tid, author, 1);
        END IF;

        first_cid := NULL;
        FOR c IN
            SELECT ord, body FROM (VALUES
                (1, 1, 'Ben de aynı şeyi merak ediyordum, cevaplar için şimdiden teşekkürler.'),
                (1, 2, 'Hafta sonu için kampüs çevresinde yürüyüş yapmayı düşünüyorum, katılmak isteyen olursa yazsın.'),
                (1, 3, 'Hava durumuna bakıp son anda karar vermek en iyisi, ama yağmurluk almayı unutmayın.'),
                (2, 1, 'Mercimek çorbalı günler benim için vazgeçilmez, yanına pilav ve salata çok iyi gidiyor.'),
                (2, 2, 'Izgara köfte olan günleri kaçırmıyorum, porsiyonlar da gayet yeterli.'),
                (2, 3, 'Tatlı çıkan günler ayrı bir mutluluk, menüyü önceden uygulamadan bakmak işe yarıyor.'),
                (3, 1, 'Sabah erken saatte 25 dakikalık kısa bloklarla çalışmak bende çok işe yaradı.'),
                (3, 2, 'Eski sınav sorularını çözmek en verimli yöntem, konu anlatımını sadece okumak yetmiyor.'),
                (3, 3, 'Arkadaşlarla soru çözüp birbirimize anlatmak hem eğlenceli hem kalıcı oluyor.'),
                (4, 1, 'Fakülte binalarının üst kat koridorları öğleden sonra oldukça sakin oluyor.'),
                (4, 2, 'Hava güzelken kampüsteki ağaçlı alanlar kitap okumak için harika.'),
                (4, 3, 'Kütüphanenin grup çalışma odaları boşken bireysel çalışmaya da uygun.'),
                (5, 1, 'Çamaşırhane için hafta içi sabah saatlerini deneyin, daha az kalabalık oluyor.'),
                (5, 2, 'Odaya sağlam bir uzatma kablosu ve küçük bir raf getirmek hayat kurtarıyor.'),
                (5, 3, 'Oda arkadaşınızla baştan kuralları konuşmak sonradan çıkacak sorunları önlüyor.'),
                (6, 1, 'Geçen ay katıldığım fotoğrafçılık gezisi çok keyifliydi, herkese öneririm.'),
                (6, 2, 'Kariyer günleri etkinlikleri sektörden insanlarla tanışmak için iyi bir fırsat.'),
                (6, 3, 'İlk etkinliğe tek başıma gittim ama kısa sürede yeni arkadaşlar edindim.'),
                (7, 1, 'Sefiller okuyorum, uzun ama sürükleyici. Tavsiye ederim.'),
                (7, 2, 'Kısa hikâyeler sınav döneminde okumak için ideal, ben bu aralar onlara yöneldim.'),
                (7, 3, 'Atomik Alışkanlıklar kitabı düzen kurmak isteyenler için güzel bir başlangıç.'),
                (8, 1, 'Akşam geç saatte bir ek sefer gerçekten çok işe yarar, bu önerinin yetkililere iletilmesi güzel olur.'),
                (8, 2, 'Sefer saatlerinin uygulamada görünmesi de planlamayı kolaylaştırır.'),
                (8, 3, 'Sınav haftalarında kütüphane çıkışına yakın bir ek saat çok yararlı olur.'),
                (9, 1, 'Bu aralar belgesel izlemek bana iyi geliyor, kısa bölümler halinde olması da güzel.'),
                (9, 2, 'Eski bir komedi dizisini baştan izlemeye başladım, sınav stresinden uzaklaşmak için birebir.'),
                (9, 3, 'Hafta sonu arkadaşlarla film gecesi yapmak en iyisi.'),
                (10, 1, 'Bildirimleri kapatmak ve ana ekranı sadeleştirmek ilk adım olarak çok işe yaradı.'),
                (10, 2, 'Ders çalışırken telefonu başka odaya bırakıyorum, ilk günler zor ama alışılıyor.'),
                (10, 3, 'Ekran süresi sınırı koymak ve haftalık rapora bakmak motive edici.'),
                (11, 1, 'Tek sayfa, net ve sade bir CV ile projelerinize bağlantı vermek yeterli.'),
                (11, 2, 'Kulüp ve gönüllülük deneyimlerini mutlaka yazın, işverenler bunlara önem veriyor.'),
                (11, 3, 'Başvuru yapacağınız pozisyona göre CV içeriğini her seferinde küçük de olsa uyarlayın.'),
                (12, 1, 'Genç Gölü çevresi ve şehrin yöresel yemekleri ilk gösterilecek yerler olmalı.'),
                (12, 2, 'Kahvaltı için şehir merkezindeki yöresel mekanlar misafirlere hep çok güzel geliyor.'),
                (12, 3, 'Hava uygunsa yakın doğa yürüyüşü rotaları da çok sevilir.'),
                (13, 1, 'Haftada üç gün 20 dakika ile başlayın, süreyi sonradan artırın, sürdürülebilir olması önemli.'),
                (13, 2, 'Arkadaşla birlikte sözleşip gitmek devamlılığı çok artırıyor.'),
                (13, 3, 'Kampüsteki açık alanlarda sabah yürüyüşü ve koşu ile başlamak gayet yeterli.'),
                (14, 1, 'Konu özeti çıkarmak için kullanıyorum ama kaynağı mutlaka kendim doğruluyorum.'),
                (14, 2, 'Ödevi onun yerine yaptırmak yerine anlamadığım kısmı açıklatmak için kullanmak daha doğru.'),
                (14, 3, 'Verdiği bilgileri her zaman ders notları ve kitapla karşılaştırmak gerekiyor.')
            ) cv(tix, ord, body)
            WHERE tix = t.ix
            ORDER BY ord
        LOOP
            idx := 1 + (t.ix * 3 + c.ord) % n;
            commenter := uids[idx];
            IF commenter = author THEN
                commenter := uids[1 + idx % n];
            END IF;
            INSERT INTO forum_comment (topic_id, user_id, depth, body, created_at, updated_at)
            VALUES (tid, commenter, 0, c.body, ts + c.ord * interval '53 minutes', ts + c.ord * interval '53 minutes')
            RETURNING id INTO cid;
            IF first_cid IS NULL THEN
                first_cid := cid;
            END IF;
            FOR k IN 1..((t.ix + c.ord) % 4) LOOP
                liker := uids[1 + (t.ix * 3 + c.ord + k + 1) % n];
                IF liker <> commenter THEN
                    INSERT INTO forum_comment_like (comment_id, user_id, created_at)
                    VALUES (cid, liker, ts + c.ord * interval '53 minutes' + k * interval '9 minutes')
                    ON CONFLICT DO NOTHING;
                END IF;
            END LOOP;
        END LOOP;

        -- Konu sahibinden ilk yoruma kisa yanit
        IF first_cid IS NOT NULL THEN
            INSERT INTO forum_comment (topic_id, user_id, parent_comment_id, root_comment_id, depth, body, created_at, updated_at)
            VALUES (tid, author, first_cid, first_cid, 1,
                    CASE t.ix % 3 WHEN 0 THEN 'Teşekkürler, çok faydalı bir öneri oldu.'
                                  WHEN 1 THEN 'Güzel fikir, deneyip sonucu yazarım.'
                                  ELSE 'Katılıyorum, diğer önerileri de merak ediyorum.' END,
                    ts + interval '4 hours', ts + interval '4 hours');
        END IF;

        -- Konu begenileri (konu sahibi kendi konusunu begenmez)
        FOR k IN 1..(3 + t.ix % 5) LOOP
            liker := uids[1 + (t.ix * 3 + k) % n];
            IF liker <> author THEN
                INSERT INTO forum_topic_like (topic_id, user_id, created_at)
                VALUES (tid, liker, ts + k * interval '31 minutes')
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;

    -- Sayaclar: eklenen satirlardan hesaplanir
    UPDATE forum_comment fc SET like_count = (SELECT COUNT(*) FROM forum_comment_like l WHERE l.comment_id = fc.id)
     WHERE fc.topic_id IN (SELECT id FROM forum_topic WHERE idem_key LIKE 'seed-v1600-%');
    UPDATE forum_comment p SET reply_count = (SELECT COUNT(*) FROM forum_comment r WHERE r.parent_comment_id = p.id)
     WHERE p.topic_id IN (SELECT id FROM forum_topic WHERE idem_key LIKE 'seed-v1600-%');
    UPDATE forum_topic ft SET
        comment_count = (SELECT COUNT(*) FROM forum_comment fc WHERE fc.topic_id = ft.id AND fc.deleted_at IS NULL AND fc.status = 'ACTIVE'),
        like_count = (SELECT COUNT(*) FROM forum_topic_like l WHERE l.topic_id = ft.id),
        last_activity_at = GREATEST(ft.created_at, COALESCE((SELECT MAX(fc.created_at) FROM forum_comment fc WHERE fc.topic_id = ft.id), ft.created_at))
     WHERE ft.idem_key LIKE 'seed-v1600-%';
END
$seed$;
