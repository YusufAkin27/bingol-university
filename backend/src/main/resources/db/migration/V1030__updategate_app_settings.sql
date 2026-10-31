-- UPDATEGATE: zorunlu guncelleme ekrani ayarlari (yonetici panelinden duzenlenir).
-- update_message_*: istege bagli kisa metin (bos = istemci varsayilani); store_package_android: Play paket adi;
-- apple_app_id_ios: yalniz rakam (bos = iOS magaza adresi uretilmez). H2/PostgreSQL uyumlu "yoksa ekle".

INSERT INTO app_setting (setting_key, setting_value)
SELECT 'update_message_tr', '' WHERE NOT EXISTS (SELECT 1 FROM app_setting WHERE setting_key = 'update_message_tr');

INSERT INTO app_setting (setting_key, setting_value)
SELECT 'update_message_en', '' WHERE NOT EXISTS (SELECT 1 FROM app_setting WHERE setting_key = 'update_message_en');

INSERT INTO app_setting (setting_key, setting_value)
SELECT 'update_message_ar', '' WHERE NOT EXISTS (SELECT 1 FROM app_setting WHERE setting_key = 'update_message_ar');

INSERT INTO app_setting (setting_key, setting_value)
SELECT 'store_package_android', 'tr.com.bukampus.app'
WHERE NOT EXISTS (SELECT 1 FROM app_setting WHERE setting_key = 'store_package_android');

INSERT INTO app_setting (setting_key, setting_value)
SELECT 'apple_app_id_ios', '' WHERE NOT EXISTS (SELECT 1 FROM app_setting WHERE setting_key = 'apple_app_id_ios');
