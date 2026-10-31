package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.UnsubscribeTokens;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Sablon degiskenleri, adres maskeleme ve (varsa) mail modulunun abonelik baglantisi yardimcilari. */
@Component
public class MailCampaignSupport {

    private final String publicUrl;
    private final ObjectProvider<UnsubscribeTokens> unsubscribe;
    private final CatalogService catalog;

    public MailCampaignSupport(@Value("${app.support.track-base-url:http://localhost:8090}") String publicUrl,
                               ObjectProvider<UnsubscribeTokens> unsubscribe, CatalogService catalog) {
        this.catalog = catalog;
        this.publicUrl = publicUrl.endsWith("/") ? publicUrl.substring(0, publicUrl.length() - 1) : publicUrl;
        this.unsubscribe = unsubscribe;
    }

    /** Bir aliciya ozgu degiskenler (izinli kume; kuyruk satirinda yalniz bunlar tutulur). */
    public Map<String, String> recipientVars(Long userId, String email, String displayName, String department,
                                             String faculty, Short classYear, Lang lang) {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("ad", nz(displayName));
        m.put("eposta", nz(email));
        // DB'deki kanonik Turkce ad alicinin dilinde gosterilir (katalogda yoksa aynen)
        m.put("bolum", nz(catalog.departmentName(department, faculty, lang)));
        m.put("fakulte", nz(catalog.facultyName(faculty, lang)));
        m.put("sinif", classYear == null ? "" : String.valueOf(classYear));
        m.put("uygulamaUrl", publicUrl);
        UnsubscribeTokens tokens = unsubscribe.getIfAvailable();
        String url = tokens == null || email == null ? null : tokens.url(email, lang, Instant.now());
        m.put("abonelikCikUrl", url == null ? publicUrl : url);
        return m;
    }

    /** Onizleme icin ornek degerler. */
    public Map<String, String> sampleVariables() {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("ad", "Ayşe Yılmaz");
        m.put("eposta", "ayse.yilmaz@bingol.edu.tr");
        m.put("bolum", "Bilgisayar Mühendisliği");
        m.put("fakulte", "Mühendislik Fakültesi");
        m.put("sinif", "2");
        m.put("uygulamaUrl", publicUrl);
        m.put("abonelikCikUrl", publicUrl + "/abonelik-onizleme");
        return m;
    }

    /** "ali.veli@bingol.edu.tr" -> "a***@bingol.edu.tr". */
    public String mask(String address) {
        if (address == null || address.isBlank()) {
            return "?";
        }
        int at = address.indexOf('@');
        if (at < 1) {
            return "***";
        }
        return address.charAt(0) + "***" + address.substring(at);
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
