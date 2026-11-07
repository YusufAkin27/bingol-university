-- FIX-P08 (A07#5): V200 yalniz grade sutununu ekledi; class_year dolu ama grade bos eski kullanicilar sinif hedefli
-- duyuru/sinav kapsaminda (grade ile eslesir) sessizce disarida kaliyordu. Kural ProfileService.gradeOfClassYear ile ayni:
-- 0 = PREP, 1..6 = "1".."6"; baska degerler (ornek 7+) grade almaz. Geriye uyumlu, yalniz bos grade doldurulur,
-- tekrar calistirmak zararsiz. Yeni gonderim yapmaz; gecmis duyurular tekrar bildirilmez (notified_at korunur).
UPDATE app_user
   SET grade = CASE WHEN class_year = 0 THEN 'PREP' ELSE CAST(class_year AS VARCHAR(8)) END
 WHERE grade IS NULL
   AND class_year IS NOT NULL
   AND class_year BETWEEN 0 AND 6
   AND deleted_at IS NULL;
