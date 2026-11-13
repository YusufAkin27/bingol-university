-- Gunun menusu push'u: gunde en cok BIR gonderim (idempotens kaydi) + yonetici acma/kapama ayari.
-- Yalniz tarih ve sayi tutulur; kisisel veri yok. Satir, o gun icin gonderim denemesinin yapildigini gosterir
-- (QUEUED: kuyruga yazildi, NO_MENU: o gun menu yok, FAILED: yazim sirasinda hata; yeniden denenmez).
CREATE TABLE daily_menu_push_log (
    push_date      DATE        PRIMARY KEY,
    outcome        VARCHAR(16) NOT NULL,
    enqueued_count INTEGER     NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO app_setting (setting_key, setting_value, updated_at)
VALUES ('daily_menu_push_enabled', 'true', now())
ON CONFLICT (setting_key) DO NOTHING;
