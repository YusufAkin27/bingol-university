-- V1640 (Kampus Forum): ogrenci agzindan, gunluk dille yazilmis ek tartisma konulari + yorumlar + begeniler
-- (kullanici istegi: "daha turkce kelimeler, ogrenci dilinde, hatali/yanlis cumleler olsun"). Yazim hatalari ve
-- gunluk konusma dili BILEREK korunmustur. V1600 ile ayni kurallar: mevcut AKTIF ve e-postasi dogrulanmis ilk 10
-- kullanici (id sirasiyla) yazar olarak atanir, bildirim/push GONDERILMEZ, sayaclar eklenen satirlardan hesaplanir,
-- idempotent (idem_key 'seed-v1640-%' varsa atlar), 3'ten az aktif kullanici varsa atlar.
-- Silmek icin: DELETE FROM forum_topic WHERE idem_key LIKE 'seed-v1640-%' (bagli satirlar once silinmelidir).

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
    IF EXISTS (SELECT 1 FROM forum_topic WHERE idem_key LIKE 'seed-v1640-%') THEN
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
            (1,  'yemekhane',     FALSE, 'abi yemekhanede pilav hep az geliyo yaw',
                 'valla herkes ayni seyi diyo ama hala duzelmedi. ogle arasi sirada 20 dk bekleyip tabagi alinca pilav 3 kasik. siz de mi boyle yasiyosunuz yoksa ben mi sanssizim'),
            (2,  'dersler',       FALSE, 'vize haftasi kurtarin beni kimse notlari paylasmiyo',
                 'arkadaslar bu hafta 4 vize var hocam konuyu anlatirken hic bisey anlamadim. kimde duzgun not varsa atsin lutfen yoksa gecemiycem. karsilik olarak cay ismarlarim'),
            (3,  'kampus-yasami', FALSE, 'kutuphanede priz kavgasi bitmiyo',
                 'sabah 8de gidiyom yine de priz yok. herkes sarj aletiyle geliyo oturuyo kalkmiyo. bi cozum bulunsa iyi olur ya bence uzatma kablosu koysunlar'),
            (4,  'yurtlar',       TRUE,  'yurtta gece 2de ses yapan oda arkadasi ne yapilir',
                 'oda arkadasim her gece geç saate kadar oyun oynuyo hem de sesli. defalarca uyardim anlamiyo. yurt mudurune mi soylesem yoksa kendi aramizda mi halletsem bilemedim'),
            (5,  'serbest-kursu', FALSE, 'bu aksam mac var nerede izliyoruz',
                 'kardesler bu aksamki maci beraber izleyelim derim. yurtta televizyon sesi kisik oluyo. sehirde bi kafe bilen var mi ogrenciye indirim yapan'),
            (6,  'etkinlikler',   FALSE, 'kulup etkinligine ilk defa gidicem utaniyorum',
                 'arkadaslar fotograf kulubunun gezisine yazildim ama kimseyi tanimiyorum. ilk gun cok mu garip olur ya. tecrubesi olan var mi'),
            (7,  'oneri-sikayet', FALSE, 'otobus saatleri hakkinda bi sey diyecem',
                 'aksam 6dan sonra servis cok seyrek geliyo. ders cikisi 40 dk bekledim dun. bi ek sefer konulsa cok iyi olurdu bence. siz ne dersiniz'),
            (8,  'gundem',        FALSE, 'staj basvurusu icin cv hazirladim bakar misiniz',
                 'ilk defa cv yaziyom yanlis yaptigim yerler vardir muhtemelen. sadece okul ve kulup deneyimi var baska bisey yok. bos birakmak mi lazim yoksa bisey uydurmak mi dogru yani'),
            (9,  'dersler',       FALSE, 'programlama dersine hic calismadim ne yapayim',
                 'final haftasina 10 gun kaldi ve ben daha donguleri bile oturtamadim. sifirdan baslasam yetisir mi sizce. youtube dan hangi hocayi izleyim onerisi olan varsa yazsin'),
            (10, 'serbest-kursu', TRUE,  'gece 3 oldu uyuyamiyorum dertlesek mi',
                 'sinav stresi mi ne bilmiyorum gozume uyku girmiyo. siz ne yapiyosunuz uyku gelmeyince. kitap okumak da tutmadi telefona bakinca daha kotu oluyo'),
            (11, 'yemekhane',     FALSE, 'bugunku menude tavuk var mi yok mu kimse bilmiyo mu',
                 'uygulamada menu gozukmuyo guncellenmemis galiba. ogle yemegine gitmeden once bilen yazsin lutfen yoksa bos yere yuruyecem'),
            (12, 'kampus-yasami', FALSE, 'kampuste kaybolan montum bulundu mu',
                 'dun muhendislik binasinda siyah mont unuttum. icinde cuzdan yok ama kimlik kartim vardi. bulan veya goren olursa yazarsa cok sevinirim'),
            (13, 'etkinlikler',   FALSE, 'konser var mi bu ay ben mi gormedim',
                 'her sene bahar senligi olur ya bu sene yok mu. afis gormedim hic. bilen birisi varsa soylesin bi grup kurup gidelim'),
            (14, 'oneri-sikayet', FALSE, 'wifi cok yavas ya sinif icinde hic cekmiyo',
                 'derste sunum yapicaktim internet kesildi rezil oldum. kampusun her yerinde mi boyle yoksa sadece bizim binada mi. bilgi islem bi bakmali bence'),
            (15, 'serbest-kursu', FALSE, 'harcliklari nasil yetirebiliyosunuz ay sonunu',
                 'ay ortasinda para bitiyo benim. kantinde bir seyler alinca hemen eriyo. tasarruf icin yolunuz varsa paylasin lutfen ben de deneyeyim'),
            (16, 'yurtlar',       FALSE, 'yurtta camasir makinesi hep dolu ne zaman bos olur',
                 'hafta sonu aksami gittim 3 kisi sirada bekliyodu. sabah erkenden mi gitmek lazim yoksa hafta ici mi daha az kalabalik. tecrubeniz neyse yazin'),
            (17, 'gundem',        FALSE, 'bingolde ogrenciler icin ek is var mi',
                 'part time calismak istiyorum ama ders programim dolu sadece hafta sonu uygun. kafe ya da kitapci bilen var mi ogrenci alan'),
            (18, 'dersler',       FALSE, 'hoca derse hic gelmiyo devamsizlik nasil olcak',
                 'bu hafta da gelmedi ama yoklama listesi imzalaniyo diyorlar. sonra devamsizliktan kalirsak ne olacak bilen var mi yonetmelik ne diyo')
        ) v(ix, slug, anon, title, body)
        ORDER BY ix
    LOOP
        SELECT id INTO cat FROM forum_category WHERE slug = t.slug;
        IF cat IS NULL THEN
            CONTINUE;
        END IF;
        author := uids[1 + (t.ix * 5 + 2) % n];
        ts := now() - ((19 - t.ix) * interval '6 hours') - interval '35 minutes';

        INSERT INTO forum_topic (user_id, category_id, title, body, anonymous, idem_key, created_at, updated_at, last_activity_at)
        VALUES (author, cat, t.title, t.body, t.anon, 'seed-v1640-' || t.ix, ts, ts, ts)
        RETURNING id INTO tid;
        IF t.anon THEN
            INSERT INTO forum_anon_alias (topic_id, user_id, n) VALUES (tid, author, 1);
        END IF;

        first_cid := NULL;
        FOR c IN
            SELECT ord, body FROM (VALUES
                (1, 1, 'aynen abi ben de ayni seyi yasadim hic duzelmiyo'),
                (1, 2, 'valla bence sikayet kutusuna yazmak lazim kimse yazmadigi icin degismiyo'),
                (1, 3, 'ya bugun gittim yine ayni durum bi sey olmuyo bosver'),
                (2, 1, 'bende var atiyim sana akşama kadar bekle'),
                (2, 2, 'hocanin slaytlari ogrenci bilgi sisteminde yuklu bak orda var'),
                (2, 3, 'gecmis sinavlari coz bence en iyisi o ben hep oyle yapiyom'),
                (3, 1, 'ben 3 kat ust koridorda calisiyom orda priz bol kimse bilmiyo'),
                (3, 2, 'sabah 7 de gelcen o zaman olur ya cok erken kimse yok'),
                (3, 3, 'uzatma kablosu getir bence herkes oyle yapiyo zaten'),
                (4, 1, 'once kendi aranizda konus sonra mudure git direk sikayet etme'),
                (4, 2, 'kulaklik al alacaksin diye soyle belki anlar'),
                (4, 3, 'yurt mudurune yazili ver bence daha ciddiye aliyolar'),
                (5, 1, 'ben varim yurttan bi kac kisi gideriz'),
                (5, 2, 'merkezdeki cay ocaginda maca izliyolar oraya git bedava'),
                (5, 3, 'saat kacta basliyo mac onu yazmamissin ki'),
                (6, 1, 'merak etme herkes cok samimi ben ilk gelisimde hic yadirgamadim'),
                (6, 2, 'git git pisman olmazsin ya yeni arkadas bulursun'),
                (6, 3, 'yanina bi arkadas al ilk sefer rahat olur'),
                (7, 1, 'bende ayni sey oldu dun 35 dk bekledim cok sacma'),
                (7, 2, 'bi dilekce yazalim hep beraber imza toplayalim'),
                (7, 3, 'servis saatlerinin hepsi eski olabilir guncel liste var mi'),
                (8, 1, 'sadece bir sayfa olsun fazla yazma kimse okumuyo'),
                (8, 2, 'projelerin varsa onlari yaz ama uydurma sorarlar cunku'),
                (8, 3, 'isim soyisim yazisi buyuk olsun ve foto koyma bence'),
                (9, 1, 'o hocanin dersi zor degil sadece ders notlarini tekrar et yeter'),
                (9, 2, 'ben de sifirdan basladim gecdim sen de yaparsin merak etme'),
                (9, 3, 'her gun 1 saat calis 10 gunde olur diyorum'),
                (10, 1, 'ben muzik dinleyip yatiyom bazen ise yariyo'),
                (10, 2, 'sicak sut ic ya da kitap oku telefonu uzaga koy'),
                (10, 3, 'aynisi bende de var sinavlar bitsin rahatlariz'),
                (11, 1, 'bugun tavuk yok kofte var yeni baktim'),
                (11, 2, 'uygulamaya girip menuye bak guncellenmis olabilir'),
                (11, 3, 'sabah yazdim bile cevap veren yok ya'),
                (12, 1, 'guvenlige sordun mu orada kayip esya bolumu var'),
                (12, 2, 'ben gordum galiba muhendislik girisinde asili duruyodu'),
                (12, 3, 'kimlik kartin varsa hemen bildir kotuye kullanilmasin'),
                (13, 1, 'bu sene var diyolar ama tarih belli degil'),
                (13, 2, 'kulup baskanlarina sorsan bilirler'),
                (13, 3, 'ben de gitmek istiyom grup kuralim'),
                (14, 1, 'bizim binada da cekmiyo ozellikle ogle saatlerinde'),
                (14, 2, 'hotspot acmak zorunda kaldim ben de'),
                (14, 3, 'bilgi islem sayfasindan talep olustur belki ise yarar'),
                (15, 1, 'haftalik butce yap ben oyle yapiyom ay sonu rahat geciyo'),
                (15, 2, 'yemekhane yemegi ucuz ona ek olarak disardan az al'),
                (15, 3, 'kantin yerine evden bisey getirmek cok daha iyi'),
                (16, 1, 'sabah 7 8 arasi bos oluyo hep orda yikiyom'),
                (16, 2, 'hafta ici ogleden once gitmek lazim akşam dolu oluyo'),
                (16, 3, 'cuma gunleri herkes eve gittigi icin bos oluyo'),
                (17, 1, 'merkezdeki kitapcida ilan gormustum sor bi'),
                (17, 2, 'kariyer merkezine yaz bazen ogrenci icin ilan oluyo'),
                (17, 3, 'hafta sonu icin kafelerde garson ariyolar oyle duydum'),
                (18, 1, 'yonetmelige gore yuzde 30 devamsizlik hakkin var ama bak yoklamaya'),
                (18, 2, 'bolum baskanligina yazili sikayet gonderirsen sonuc verir'),
                (18, 3, 'ben de ayni seyi yasadim o donem telafi dersi koydular')
            ) cv(tix, ord, body)
            WHERE tix = t.ix
            ORDER BY ord
        LOOP
            idx := 1 + (t.ix * 5 + c.ord + 3) % n;
            commenter := uids[idx];
            IF commenter = author THEN
                commenter := uids[1 + idx % n];
            END IF;
            INSERT INTO forum_comment (topic_id, user_id, depth, body, created_at, updated_at)
            VALUES (tid, commenter, 0, c.body, ts + c.ord * interval '41 minutes', ts + c.ord * interval '41 minutes')
            RETURNING id INTO cid;
            IF first_cid IS NULL THEN
                first_cid := cid;
            END IF;
            FOR k IN 1..((t.ix + c.ord) % 4) LOOP
                liker := uids[1 + (t.ix * 5 + c.ord + k + 4) % n];
                IF liker <> commenter THEN
                    INSERT INTO forum_comment_like (comment_id, user_id, created_at)
                    VALUES (cid, liker, ts + c.ord * interval '41 minutes' + k * interval '7 minutes')
                    ON CONFLICT DO NOTHING;
                END IF;
            END LOOP;
        END LOOP;

        -- Konu sahibinden ilk yoruma kisa, gunluk dille yanit
        IF first_cid IS NOT NULL THEN
            INSERT INTO forum_comment (topic_id, user_id, parent_comment_id, root_comment_id, depth, body, created_at, updated_at)
            VALUES (tid, author, first_cid, first_cid, 1,
                    CASE t.ix % 4 WHEN 0 THEN 'saol kardes cok sagol'
                                  WHEN 1 THEN 'eyvallah abi bi deniyim'
                                  WHEN 2 THEN 'tmm yarin bakarim bi ya'
                                  ELSE 'valla bende oyle dusunuyodum' END,
                    ts + interval '3 hours', ts + interval '3 hours');
        END IF;

        -- Konu begenileri (konu sahibi kendi konusunu begenmez)
        FOR k IN 1..(2 + t.ix % 6) LOOP
            liker := uids[1 + (t.ix * 5 + k + 1) % n];
            IF liker <> author THEN
                INSERT INTO forum_topic_like (topic_id, user_id, created_at)
                VALUES (tid, liker, ts + k * interval '27 minutes')
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;

    -- Sayaclar: eklenen satirlardan hesaplanir
    UPDATE forum_comment fc SET like_count = (SELECT COUNT(*) FROM forum_comment_like l WHERE l.comment_id = fc.id)
     WHERE fc.topic_id IN (SELECT id FROM forum_topic WHERE idem_key LIKE 'seed-v1640-%');
    UPDATE forum_comment p SET reply_count = (SELECT COUNT(*) FROM forum_comment r WHERE r.parent_comment_id = p.id)
     WHERE p.topic_id IN (SELECT id FROM forum_topic WHERE idem_key LIKE 'seed-v1640-%');
    UPDATE forum_topic ft SET
        comment_count = (SELECT COUNT(*) FROM forum_comment fc WHERE fc.topic_id = ft.id AND fc.deleted_at IS NULL AND fc.status = 'ACTIVE'),
        like_count = (SELECT COUNT(*) FROM forum_topic_like l WHERE l.topic_id = ft.id),
        last_activity_at = GREATEST(ft.created_at, COALESCE((SELECT MAX(fc.created_at) FROM forum_comment fc WHERE fc.topic_id = ft.id), ft.created_at))
     WHERE ft.idem_key LIKE 'seed-v1640-%';
END
$seed$;
