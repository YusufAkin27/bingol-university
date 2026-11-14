package edu.bingol.backend.academician;

/**
 * Devamsizlik sinir degerlendirmesi: API'deki atRisk/overLimit ve otomatik ogrenci uyarisi AYNI fonksiyondan gelir.
 * Duzey 2 = sinira ulasildi ya da asildi; duzey 1 = bir devamsizlik daha (yeni bir oturumda) siniri doldurur ve ogrencinin
 * en az bir devamsizligi var (devamsizligi olmayana risk uyarisi verilmez); 0 = durum temiz ya da sinir yok.
 * COUNT: devamsizlik &gt;= deger. PERCENT: devamsizlik*100 &gt;= yuzde*oturum (tam sayi karsilastirma, yuvarlama yok;
 * oturum sayisi 0 iken ulasilmaz).
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
        return new Standing(level(type, value, total, absent));
    }

    public static int level(AcCourse.LimitType type, Integer value, int total, int absent) {
        if (type == null || value == null || value < 1) {
            return 0;
        }
        if (reached(type, value, total, absent)) {
            return 2;
        }
        return absent >= 1 && reached(type, value, total + 1, absent + 1) ? 1 : 0;
    }

    private static boolean reached(AcCourse.LimitType type, int value, int total, int absent) {
        return switch (type) {
            case COUNT -> absent >= value;
            case PERCENT -> total > 0 && (long) absent * 100 >= (long) value * total;
        };
    }
}
