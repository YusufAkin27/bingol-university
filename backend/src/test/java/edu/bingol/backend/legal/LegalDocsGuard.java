package edu.bingol.backend.legal;

import static org.junit.jupiter.api.Assertions.fail;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Belge (docs/legal) dosyalarina dayanan testlerin "belge gorunmuyor" durumu.
 *
 * <p>Yalniz {@code backend/} baglayan yerel Docker komutunda {@code ../docs} yoktur; orada testler ATLANIR (eskiden de
 * boyleydi). Ama CI'da ({@code CI} ortam degiskeni) ya da {@code -Dlegal.docs.required=true} ile belge yoksa test
 * SESSIZCE gecmek yerine BASARISIZ olur: yanlis yapilandirilmis bir CI "yesil" gorunup hukuki metin denetimini atlamasin.
 */
final class LegalDocsGuard {

    private LegalDocsGuard() {}

    static boolean strict() {
        String ci = System.getenv("CI");
        return Boolean.getBoolean("legal.docs.required") || (ci != null && !ci.isBlank() && !ci.equalsIgnoreCase("false"));
    }

    /** Belge varsa devam; yoksa strict ise basarisiz, degilse atla. */
    static void requireDocs(boolean present, String message) {
        require(present, message, strict());
    }

    static void require(boolean present, String message, boolean strict) {
        if (present) {
            return;
        }
        if (strict) {
            fail(message + " (CI/legal.docs.required: belge yoksa test atlanamaz; testi repo kokunden calistirin)");
        }
        assumeTrue(false, message);
    }
}
