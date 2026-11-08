-- V1690 (Kampus Forum): ikinci tohum dalgasi (kullanici istegi 2026-11-08: daha fazla tartisma olsun).
-- V1600 ile ayni kurallar: mevcut AKTIF ve e-postasi dogrulanmis ilk kullanicilar yazar atanir, ham SQL oldugundan
-- bildirim/push GONDERILMEZ, sayaclar eklenen satirlardan hesaplanir. Gorunen begeni ekleri V1700'de.
-- Idempotent: idem_key 'seed-v1690-%' olan konu varsa hicbir sey yapmaz. 3'ten az aktif kullanici varsa atlar.
-- Silmek icin: DELETE FROM forum_topic WHERE idem_key LIKE 'seed-v1690-%'.

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
    IF EXISTS (SELECT 1 FROM forum_topic WHERE idem_key LIKE 'seed-v1690-%') THEN
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
            (1,  'dersler',        FALSE, 'Vize haftasında uykusuz kalmamak için ne yapıyorsunuz?',
                 'Sınav haftasında gece geç saate kadar çalışınca ertesi gün hiçbir şey hatırlamıyorum. Uyku düzenini bozmadan nasıl çalışıyorsunuz?'),
            (2,  'yemekhane',      FALSE, 'Yemekhanede öğle yoğunluğu: hangi saatte gitmek en iyisi?',
                 'Öğle arası sıra çok uzuyor. Siz hangi saatte gidince hem sıra beklemiyor hem de yemeklerin bitmediğini görüyorsunuz?'),
            (3,  'kampus-yasami',  FALSE, 'Kampüste en güzel gün batımını nereden izleyebilirim?',
                 'Akşamüstü kafa dinlemek için güzel bir manzara arıyorum. Kampüs içinde ya da yakınında önerdiğiniz bir yer var mı?'),
            (4,  'yurtlar',        TRUE,  'Yurtta sessiz saatler konusunda ne yapıyorsunuz?',
                 'Gece geç saatte koridorda sesler olunca ders çalışmak zorlaşıyor. Siz bu durumu nasıl çözüyorsunuz, kime başvuruyorsunuz?'),
            (5,  'etkinlikler',    FALSE, 'Bu dönem hangi söyleşi ve seminerlere gitmeyi düşünüyorsunuz?',
                 'Takvimde birkaç ilginç etkinlik gördüm ama hepsine yetişemem. Sizin listenizde neler var, tavsiye eden var mı?'),
            (6,  'serbest-kursu',  FALSE, 'Ders dışında yeni bir dil öğrenmek isteyenler buraya',
                 'Bu dönem İngilizcenin yanında ikinci bir dil öğrenmeyi düşünüyorum. Hangi uygulamaları ya da yöntemleri kullanıyorsunuz?'),
            (7,  'oneri-sikayet',  FALSE, 'Kütüphane çalışma saatleri hakkında önerim var',
                 'Sınav dönemlerinde kütüphane daha geç saate kadar açık olsa çok işe yarar. Siz de benim gibi düşünüyor musunuz?'),
            (8,  'gundem',         FALSE, 'Mezun olanlar: ilk iş başvurusunda en çok neye takıldınız?',
                 'Mezuniyete yaklaşırken biraz kaygılıyım. İlk iş başvurularında yaşadığınız zorluklar ve işe yarayan ipuçları neler?'),
            (9,  'serbest-kursu',  FALSE, 'Kampüste fotoğraf çekmeyi sevenler var mı?',
                 'Telefonla kampüsün güzel köşelerini çekmeyi seviyorum. Birlikte fotoğraf gezisi yapmak isteyen olursa yazsın.'),
            (10, 'dersler',        FALSE, 'Not tutmak için kağıt mı dijital mi kullanıyorsunuz?',
                 'Derste elle not tutmak mı yoksa tablet ya da telefonla mı daha verimli oluyor? Sizin tecrübeleriniz neler?'),
            (11, 'kampus-yasami',  FALSE, 'Hafta sonu şehir merkezinde ucuz ve güzel kahvaltı mekanları',
                 'Arkadaşlarla hafta sonu kahvaltıya çıkmak istiyoruz. Bütçeye uygun ve güzel mekan önerisi olan var mı?'),
            (12, 'yurtlar',        FALSE, 'Yurtta ortak mutfak kullanımı için kurallar',
                 'Ortak mutfakta bulaşık ve temizlik konusunda sürekli sorun çıkıyor. Sizde nasıl bir düzen kuruldu, işe yarayan bir yöntem var mı?'),
            (13, 'etkinlikler',    FALSE, 'Yeni bir kulüp kurmak için nereden başlamalıyım?',
                 'İlgi alanıma uygun bir topluluk yok gibi duruyor, kendim kurmayı düşünüyorum. Başvuru süreci ve ilk adımlar konusunda tecrübesi olan var mı?'),
            (14, 'oneri-sikayet',  FALSE, 'Kampüs içinde bisiklet yolu ve park alanı olsun',
                 'Bisikletle gelen arkadaşlar için güvenli bir park alanı çok işe yarar. Siz bu konuda ne düşünüyorsunuz?'),
            (15, 'gundem',         FALSE, 'Burs ve destek programları hakkında bildiklerinizi paylaşır mısınız?',
                 'Bu dönem başvurabileceğim burs ve destek programlarını araştırıyorum. Başvuru yaptıysanız süreç nasıldı?'),
            (16, 'serbest-kursu',  TRUE,  'Sınav kaygısıyla nasıl başa çıkıyorsunuz?',
                 'Sınav yaklaşınca elim ayağım titriyor. Nefes egzersizi, yürüyüş ya da başka işe yarayan bir şey denediyseniz paylaşır mısınız?'),
            (17, 'dersler',        FALSE, 'Ortak ders notlarını paylaşabileceğimiz bir düzen kuralım mı?',
                 'Her dersin notunu herkes tek tek tutuyor. Bir araya gelip not paylaşımı yapsak hepimiz için daha kolay olur, ne dersiniz?'),
            (18, 'yemekhane',      FALSE, 'Vejetaryen ve hafif menü seçenekleri yeterli mi?',
                 'Etsiz ya da hafif yemek tercih edenler için menüde yeterli seçenek var mı? Sizin deneyiminiz nasıl?')
        ) v(ix, slug, anon, title, body)
        ORDER BY ix
    LOOP
        SELECT id INTO cat FROM forum_category WHERE slug = t.slug;
        IF cat IS NULL THEN
            CONTINUE;
        END IF;
        author := uids[1 + (t.ix * 7 + 2) % n];
        ts := now() - ((19 - t.ix) * interval '5 hours') - interval '35 minutes';

        INSERT INTO forum_topic (user_id, category_id, title, body, anonymous, idem_key, created_at, updated_at, last_activity_at)
        VALUES (author, cat, t.title, t.body, t.anon, 'seed-v1690-' || t.ix, ts, ts, ts)
        RETURNING id INTO tid;
        IF t.anon THEN
            INSERT INTO forum_anon_alias (topic_id, user_id, n) VALUES (tid, author, 1);
        END IF;
        first_cid := NULL;
        FOR c IN
            SELECT ord, body FROM (VALUES
                (1, 1, 'Ben de bunu geçen hafta düşünüyordum, güzel bir konu açmışsın.'),
                (1, 2, 'Bende en çok işe yarayan şey düzenli bir program yapmak oldu, deneyin derim.'),
                (1, 3, 'Arkadaşlarla konuşunca daha iyi fikirler çıkıyor, cevapları merakla bekliyorum.'),
                (2, 1, 'Ben genelde on bire doğru gidiyorum, sıra çok daha kısa oluyor.'),
                (2, 2, 'Öğle arası dersi olanlar için bir buçuk gibi gitmek de fena değil.'),
                (2, 3, 'Uygulamadan menüye önceden bakıp planlamak işimi kolaylaştırıyor.'),
                (3, 1, 'Spor alanlarının oradaki yükseltiden gün batımı gerçekten çok güzel görünüyor.'),
                (3, 2, 'Hava açıksa kampüsün yukarı kısmı çok güzel, arkadaşlarla gidince daha da keyifli.'),
                (3, 3, 'Ben kamerayı alıp akşamları dolaşıyorum, çok güzel kareler çıkıyor.'),
                (4, 1, 'Kulaklık ve kulak tıkacı benim hayatımı kurtardı, tavsiye ederim.'),
                (4, 2, 'Yurt yönetimine kibarca yazılı bildirim yapmak sonuç verdi bende.'),
                (4, 3, 'Oda arkadaşlarla baştan sessiz saat anlaşması yapmak en sağlıklısı.'),
                (5, 1, 'Kariyer söyleşilerine mutlaka gidin, sorularınızı önceden hazırlayın.'),
                (5, 2, 'Takvimde gördüğüm yazılım seminerine ben de katılmayı düşünüyorum.'),
                (5, 3, 'Etkinlikler genelde çok kalabalık olmuyor, soru sormak için fırsat.'),
                (6, 1, 'Günde on dakika bile olsa her gün çalışmak aralıklı uzun çalışmadan daha iyi.'),
                (6, 2, 'Dizi ve film izleyerek altyazıyla öğrenmek benim için çok eğlenceli oldu.'),
                (6, 3, 'Konuşma pratiği için dil değişimi yapacak arkadaş bulmak çok işe yarıyor.'),
                (7, 1, 'Sınav haftalarında uzatılmış saat gerçekten büyük fark yaratır, katılıyorum.'),
                (7, 2, 'Önerinin öğrenci temsilcileri aracılığıyla iletilmesi iyi olur.'),
                (7, 3, 'Gece çalışanlar için yakın çevrede sessiz bir alan daha olsa güzel olurdu.'),
                (8, 1, 'Mülakat öncesi aynada ya da arkadaşla prova yapmak ilk başvuruda çok yardımcı oldu.'),
                (8, 2, 'Kulüp ve proje deneyimlerini CV içinde net yazmak fark yaratıyor.'),
                (8, 3, 'Başvuru yapmaktan çekinmeyin, ilk denemelerde öğrenmek de kazanç.'),
                (9, 1, 'Ben de katılırım, hafta sonu için bir gün belirleyelim.'),
                (9, 2, 'Kampüsün sonbahardaki renkleri fotoğraf için harika.'),
                (9, 3, 'Telefon kamerasıyla bile çok güzel çıkıyor, bir sergi bile yapılabilir.'),
                (10, 1, 'Ben tablet kullanıyorum ama derste dikkatim dağılıyor, kağıt daha verimli geliyor.'),
                (10, 2, 'Dijital notlarda arama yapabilmek çok işime yarıyor, ikisini karışık kullanıyorum.'),
                (10, 3, 'Kısa notları elle alıp sonra temize çekmek bende kalıcılığı artırıyor.'),
                (11, 1, 'Merkezdeki yöresel kahvaltı mekanları hem uygun hem doyurucu.'),
                (11, 2, 'Hafta sonu erken gitmek lazım, yoksa yer bulmak zorlaşıyor.'),
                (11, 3, 'Arkadaş grubuyla gidince kahvaltı tabaklarını paylaşmak hesabı da düşürüyor.'),
                (12, 1, 'Nöbetçi çizelgesi yapmak bizim katta çok işe yaradı.'),
                (12, 2, 'Herkesin kendi kabını yıkayıp kaldırması kuralı en basit çözüm.'),
                (12, 3, 'Mutfak kurallarını bir kağıda yazıp asmak da hatırlatma için güzel.'),
                (13, 1, 'Önce ilgilenecek birkaç arkadaş bulun, sonra yönergeye göre başvuru yapın.'),
                (13, 2, 'Danışman hoca bulmak sürecin en önemli adımı, erkenden konuşun.'),
                (13, 3, 'İlk etkinliği küçük tutup ilgiyi görmek iyi bir başlangıç olur.'),
                (14, 1, 'Güvenli bisiklet park alanı olsa ben de bisikletle gelmeye başlarım.'),
                (14, 2, 'Kampüs içinde hız sınırı ve ayrılmış yol da güzel olur.'),
                (14, 3, 'Öneriyi yönetime iletmek için imza toplamak bile düşünülebilir.'),
                (15, 1, 'Başvuru tarihlerini takip etmek en önemli şey, duyuruları kaçırmayın.'),
                (15, 2, 'Gerekli belgeleri önceden hazırlamak işi çok hızlandırıyor.'),
                (15, 3, 'Danışman hocaya sormak da süreç konusunda net bilgi veriyor.'),
                (16, 1, 'Sınav öncesi kısa yürüyüş yapmak benim için çok iyi geliyor.'),
                (16, 2, 'Derin nefes alıp yavaş vermek sınav anında sakinleşmeme yardımcı oluyor.'),
                (16, 3, 'Kaygılıysanız bir arkadaşla konuşmak ya da kampüs psikolojik danışma birimine gitmek de iyi bir adım.'),
                (17, 1, 'Çok güzel fikir, ortak bir klasörde bölümlere göre düzenleyebiliriz.'),
                (17, 2, 'Herkesin bir ders sorumlusu olması işi kolaylaştırır.'),
                (17, 3, 'Notları paylaşırken kaynağı belirtmek de önemli, birbirimizin emeğine saygı.'),
                (18, 1, 'Vejetaryen seçenekler biraz daha artarsa herkes için daha iyi olur.'),
                (18, 2, 'Sebze yemekleri ve çorbalar bence yeterli ama çeşit artabilir.'),
                (18, 3, 'Menüde hafif seçenek günlerini işaretlemek de faydalı olurdu.')
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
            VALUES (tid, commenter, 0, c.body, ts + c.ord * interval '47 minutes', ts + c.ord * interval '47 minutes')
            RETURNING id INTO cid;
            IF first_cid IS NULL THEN
                first_cid := cid;
            END IF;
            FOR k IN 1..((t.ix + c.ord) % 4) LOOP
                liker := uids[1 + (t.ix * 3 + c.ord + k + 1) % n];
                IF liker <> commenter THEN
                    INSERT INTO forum_comment_like (comment_id, user_id, created_at)
                    VALUES (cid, liker, ts + c.ord * interval '47 minutes' + k * interval '9 minutes')
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
     WHERE fc.topic_id IN (SELECT id FROM forum_topic WHERE idem_key LIKE 'seed-v1690-%');
    UPDATE forum_comment p SET reply_count = (SELECT COUNT(*) FROM forum_comment r WHERE r.parent_comment_id = p.id)
     WHERE p.topic_id IN (SELECT id FROM forum_topic WHERE idem_key LIKE 'seed-v1690-%');
    UPDATE forum_topic ft SET
        comment_count = (SELECT COUNT(*) FROM forum_comment fc WHERE fc.topic_id = ft.id AND fc.deleted_at IS NULL AND fc.status = 'ACTIVE'),
        like_count = (SELECT COUNT(*) FROM forum_topic_like l WHERE l.topic_id = ft.id),
        last_activity_at = GREATEST(ft.created_at, COALESCE((SELECT MAX(fc.created_at) FROM forum_comment fc WHERE fc.topic_id = ft.id), ft.created_at))
     WHERE ft.idem_key LIKE 'seed-v1690-%';
END
$seed$;
