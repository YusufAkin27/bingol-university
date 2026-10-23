-- Uygulama ayarlari: iletisim bilgileri, surum kontrolu, duyuru cubugu, bakim modu (yonetici duzenler)

CREATE TABLE app_setting (
    setting_key   VARCHAR(64)   PRIMARY KEY,
    setting_value VARCHAR(1000) NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);

INSERT INTO app_setting (setting_key, setting_value) VALUES
 ('app_name', 'Bingöl Üniversitesi'),
 ('website', 'https://www.bingol.edu.tr'),
 ('contact_email', ''),
 ('support_email', ''),
 ('phone', ''),
 ('address', ''),
 ('instagram', ''),
 ('twitter', ''),
 ('youtube', ''),
 ('min_version_android', '1.0.0'),
 ('latest_version_android', '1.0.0'),
 ('store_url_android', ''),
 ('min_version_ios', '1.0.0'),
 ('latest_version_ios', '1.0.0'),
 ('store_url_ios', ''),
 ('banner_text_tr', ''),
 ('banner_text_en', ''),
 ('banner_text_ar', ''),
 ('banner_url', ''),
 ('maintenance_mode', 'false'),
 ('maintenance_message_tr', 'Sistem bakımda. Lütfen daha sonra tekrar deneyin.'),
 ('maintenance_message_en', 'The system is under maintenance. Please try again later.'),
 ('maintenance_message_ar', 'النظام قيد الصيانة. يرجى المحاولة لاحقًا.');
