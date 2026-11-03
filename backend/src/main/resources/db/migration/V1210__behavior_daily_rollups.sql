-- V1210: kullanici davranis analizi (oturum / ekran suresi) gunluk kalici ozetleri. Ayrinti: docs/ADMIN_API.md "Kullanici davranis analizi".
-- Ham olaylar (analytics_event) 45 gun saklanir; bu tablolar yalniz TOPLU sayilar tutar, kullanici kimligi YOKTUR.
-- Gun = Europe/Istanbul takvim gunu. Dolum: dbmaint.AnalyticsRollup.rollUpBehaviorDays (gece, idempotent upsert).
-- "users" = o gunun tekil kullanicisi; araliklarda toplanirsa "gun-kullanici" olur. Oturum, BASLADIGI gune sayilir.

-- Gun bazli oturum ozeti: bounce = <=1 ekran ve < 10 sn; quick_close = < 5 sn.
CREATE TABLE analytics_session_daily (
    day         DATE    NOT NULL PRIMARY KEY,
    sessions    INTEGER NOT NULL,
    users       INTEGER NOT NULL,
    total_ms    BIGINT  NOT NULL,
    bounces     INTEGER NOT NULL,
    quick_closes INTEGER NOT NULL
);

-- Gun x ekran: goruntuleme, tekil kullanici, ekranda gecen sure toplami (screen_exit.dwellMs; ortalama = dwell_ms_sum / dwell_n),
-- oturumun SON ekrani olma (exits), oturumun ILK ekrani olma (entries) ve bu ekranda baslayip bounce olan oturum sayisi.
CREATE TABLE analytics_screen_daily (
    day             DATE        NOT NULL,
    screen          VARCHAR(60) NOT NULL,
    views           INTEGER     NOT NULL,
    users           INTEGER     NOT NULL,
    dwell_ms_sum    BIGINT      NOT NULL,
    dwell_n         INTEGER     NOT NULL,
    exits           INTEGER     NOT NULL,
    entries         INTEGER     NOT NULL,
    bounce_sessions INTEGER     NOT NULL,
    PRIMARY KEY (day, screen)
);
-- Ekran bazli uzun donem sorgusu (screen, day) icin
CREATE INDEX bh_screen_daily_screen ON analytics_screen_daily (screen, day);

-- Kullanici bazli oturum aramasi ham tabloda mevcut (user_id, created_at) indeksiyle yapilir; yeni ham indeks gerekmedi.
