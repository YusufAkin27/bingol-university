-- Sinav hatirlatmasi (sinavdan 2 saat once sunucu push'u): tekrar-onleme izi.
-- reminded_starts_at = hatirlatmanin gonderildigi (ya da kullanici sinavi zaten yakin bir saatle girdigi icin gerek
-- kalmadigi) starts_at degeri. starts_at degisirse iki deger ayrisir ve sinav yeniden hatirlatilabilir.
-- NULL = henuz hatirlatilmadi. Geri doldurma YOK: gecmis sinavlar zaten pencere disindadir.
ALTER TABLE tt_exam ADD COLUMN IF NOT EXISTS reminded_starts_at TIMESTAMPTZ;

-- Tum kullanicilar uzerinde "yaklasan sinavlar" taramasi (ExamReminderJob) icin zaman indeksi.
CREATE INDEX IF NOT EXISTS exr9_exam_starts_idx ON tt_exam (starts_at);
