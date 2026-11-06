-- Gunluk menu bildirimi VARSAYILAN ACIK (kullanici karari 2026-11-06). V1271 sutunu kapali varsayilanla eklemisti.
-- Yeni satirlar acik gelir; mevcut satirlar da acilir (ozellik yeni yayinlandi, acik/kapali tercih ayrimi tutulmuyordu).
ALTER TABLE notification_pref ALTER COLUMN meal_menu SET DEFAULT TRUE;
UPDATE notification_pref SET meal_menu = TRUE WHERE meal_menu = FALSE;
