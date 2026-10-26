-- Urun adi "BÜ Kampüs" (yalnizca hala eski varsayilan degerdeyse; yonetici degistirmisse dokunma)
UPDATE app_setting SET setting_value = 'BÜ Kampüs', updated_at = now()
WHERE setting_key = 'app_name' AND setting_value = 'Bingöl Üniversitesi';
