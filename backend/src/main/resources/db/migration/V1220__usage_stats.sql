-- V1220: kullanim istatistikleri (ekran gezinme, eylem, akis, saat isi haritasi, platform/surum/bolum kirilimi).
-- Yalnizca TOPLULASTIRILMIS gunluk ozetler: hicbir tabloda kullanici kimligi yoktur ve kalicidir (KVKK).
-- Gecelik dbmaint.UsageRollup doldurur; bugun icin kismi satirlar 15 dk'da bir tazelenir (complete = false).
-- Ayrinti: docs/USAGE_STATS.md. Yalniz birincil anahtar indeksleri var (adlari tabloya ozel, cakisma yok).

-- Ham olaya platform/surum: istemci basliklarindan (X-Device-Platform / X-App-Platform, X-App-Version) gelir,
-- yalniz gece toplulastirmasinda kirilim icin okunur; ham olay zaten 45 gun sonra silinir.
ALTER TABLE analytics_event
    ADD COLUMN platform    VARCHAR(10),
    ADD COLUMN app_version VARCHAR(32);

-- Gun ozeti: gunluk aktif, olay gonderen kullanici, oturum ve ekran goruntuleme sayilari, oturum suresi (sn).
CREATE TABLE analytics_usage_day (
    day          DATE    NOT NULL PRIMARY KEY,
    dau          INTEGER NOT NULL DEFAULT 0,
    an_users     INTEGER NOT NULL DEFAULT 0,
    sessions     INTEGER NOT NULL DEFAULT 0,
    screen_views INTEGER NOT NULL DEFAULT 0,
    sess_dur_sum BIGINT  NOT NULL DEFAULT 0,
    sess_dur_n   INTEGER NOT NULL DEFAULT 0,
    complete     BOOLEAN NOT NULL DEFAULT FALSE
);

-- Ekran bazinda gun ozeti. users = o gunun tekil kullanicisi (araliklarda toplanirsa "kullanici-gun").
-- dur_*: BU ekranda gecirilen sure (bir sonraki screen_view'in props.from/ms degerinden); exits = sonraki ekrani olmayan goruntuleme.
CREATE TABLE analytics_screen_daily (
    day        DATE        NOT NULL,
    screen     VARCHAR(40) NOT NULL,
    views      INTEGER     NOT NULL,
    users      INTEGER     NOT NULL,
    dur_sum_ms BIGINT      NOT NULL DEFAULT 0,
    dur_n      INTEGER     NOT NULL DEFAULT 0,
    exits      INTEGER     NOT NULL DEFAULT 0,
    PRIMARY KEY (day, screen)
);

-- Ekran suresi dagilimi (medyan icin kova sayaclari; kova sinirlari UsageBuckets.EDGES_MS ile aynidir).
CREATE TABLE analytics_screen_dur_daily (
    day    DATE        NOT NULL,
    screen VARCHAR(40) NOT NULL,
    bucket SMALLINT    NOT NULL,
    n      INTEGER     NOT NULL,
    PRIMARY KEY (day, screen, bucket)
);

-- Eylem (screen_view/app_open/app_background disindaki olaylar) gun ozeti.
CREATE TABLE analytics_action_daily (
    day    DATE        NOT NULL,
    action VARCHAR(40) NOT NULL,
    events INTEGER     NOT NULL,
    users  INTEGER     NOT NULL,
    PRIMARY KEY (day, action)
);

-- Ekrandan ekrana gecis (gunde en cok 500 kenar).
CREATE TABLE analytics_flow_daily (
    day DATE        NOT NULL,
    src VARCHAR(40) NOT NULL,
    dst VARCHAR(40) NOT NULL,
    n   INTEGER     NOT NULL,
    PRIMARY KEY (day, src, dst)
);

-- Saat (Istanbul 0-23) bazinda oturum ve ekran goruntuleme; hafta gunu `day`dan turetilir.
CREATE TABLE analytics_hour_daily (
    day      DATE     NOT NULL,
    hour     SMALLINT NOT NULL,
    sessions INTEGER  NOT NULL DEFAULT 0,
    views    INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (day, hour)
);

-- Kirilim: kind = platform | version | faculty | department. K-anonimlik YAZILIRKEN uygulanir: gunluk kullanicisi
-- k'dan az olan gruplar 'other' altinda birlesir, 'other' de k'dan azsa hic yazilmaz (platform muaf).
CREATE TABLE analytics_segment_daily (
    day   DATE         NOT NULL,
    kind  VARCHAR(12)  NOT NULL,
    seg   VARCHAR(120) NOT NULL,
    users INTEGER      NOT NULL,
    views INTEGER      NOT NULL,
    PRIMARY KEY (day, kind, seg)
);

-- Ozellik benimseme: o gunde biten 30 gunluk pencerede ozelligi kullanan TEKIL kullanici (feature = 'all': herhangi bir
-- olay gonderen) ve ayni penceredeki MAU (activity_daily). Yalniz tamamlanmis gunler icin yazilir.
CREATE TABLE analytics_feature_snapshot (
    day     DATE        NOT NULL,
    feature VARCHAR(24) NOT NULL,
    users   INTEGER     NOT NULL,
    mau     INTEGER     NOT NULL,
    PRIMARY KEY (day, feature)
);
