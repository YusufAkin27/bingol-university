package edu.bingol.backend.academician;

/**
 * Devamsizlik sinir degerlendirmesi: API'deki atRisk/overLimit ve otomatik ogrenci uyarisi AYNI fonksiyondan gelir.
 * Duzey 2 = sinira ulasildi (devamsizlik &gt;= izinli adet, esitlikte "Sinira ulasti", ustunde "Sinir asildi"); duzey 1 = bir
 * devamsizlik daha (yeni bir oturumda) siniri doldurur ve ogrencinin en az bir devamsizligi var; 0 = temiz ya da sinir yok.
 * <ul>
 *   <li>COUNT: izinli adet = deger.</li>
 *   <li>PERCENT + planlanan ders sayisi: izinli adet = {@code max(1, floor(yuzde * planlanan / 100))}, sonra AYNI COUNT mantigi.</li>
 *   <li>PERCENT, planlanan yok: sayilan oturum sayisi {@code percent-min-sessions}'a ulasana kadar durum yok; sonra
 *       devamsizlik*100 &gt;= yuzde*sayilanOturum (tam sayi karsilastirmasi, yuvarlama yok).</li>
 * </ul>
 */
public final class AbsencePolicy {

    /** atRisk = duzey 1, overLimit = duzey 2. */
    public record Standing(int level) {
        public boolean atRisk() {
            return level == 1;
        }

        public boolean overLimit() {
            return level == 2;
        }
    }

    private AbsencePolicy() {}

    public static Standing standing(AcCourse.LimitType type, Integer value, int total, int absent) {
        return new Standing(level(type, value, null, total, absent, 0));
    }

    /** Planlanan ders sayisi ve en az oturum esigi olmadan (saf matematik). */
    public static int level(AcCourse.LimitType type, Integer value, int total, int absent) {
        return level(type, value, null, total, absent, 0);
    }

    /** Siniri su an "en fazla N devamsizlik" olarak ifade eden adet; PERCENT ve planlanan yoksa null. */
    public static Integer allowedAbsences(AcCourse.LimitType type, Integer value, Integer planned) {
        if (type == null || value == null || value < 1) {
            return null;
        }
        if (type == AcCourse.LimitType.COUNT) {
            return value;
        }
        return planned == null || planned < 1 ? null : Math.max(1, (int) ((long) value * planned / 100));
    }

    public static int level(AcCourse.LimitType type, Integer value, Integer planned, int total, int absent, int minPercentSessions) {
        if (type == null || value == null || value < 1) {
            return 0;
        }
        Integer allowed = allowedAbsences(type, value, planned);
        if (allowed != null) {
            return countLevel(allowed, absent);
        }
        if (total < minPercentSessions) {
            return 0;
        }
        if (percentReached(value, total, absent)) {
            return 2;
        }
        return absent >= 1 && percentReached(value, total + 1, absent + 1) ? 1 : 0;
    }

    private static int countLevel(int allowed, int absent) {
        if (absent >= allowed) {
            return 2;
        }
        return absent >= 1 && absent + 1 >= allowed ? 1 : 0;
    }

    private static boolean percentReached(int value, int total, int absent) {
        return total > 0 && (long) absent * 100 >= (long) value * total;
    }
}
