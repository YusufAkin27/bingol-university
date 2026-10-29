package edu.bingol.backend.mail;

import java.io.IOException;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.web.util.HtmlUtils;

/**
 * Marka ust bandi: kirmizi bandin ustunde beyaz yatay logo (mail-templates/logo.png, ~8 KB, 2x yogunluk).
 * Logo CID ile GOMULU ek olarak gonderilir ({@link MailTransport}); Gmail data: URI'yi engeller, harici URL ise
 * web dagitimina/CDN'e ve alicinin "gorselleri goster" ayarina bagli olurdu. Resim yuklenmezse alt metin
 * (marka adi, beyaz kalin) kirmizi bant uzerinde okunur. Logo dosyasi yoksa yalniz metin basligi kullanilir.
 */
public final class MailBrand {

    private static final Logger log = LoggerFactory.getLogger(MailBrand.class);

    /** HTML'deki {@code cid:} kimligi ve gomulu parcanin Content-ID'si. */
    public static final String LOGO_CID = "bu-logo";
    /** Gorunen boyut (px); dosya 2x (276x72) oldugundan retina'da keskin. */
    private static final int LOGO_WIDTH = 138;
    private static final int LOGO_HEIGHT = 36;

    private static final byte[] LOGO = load();

    private MailBrand() {
    }

    public static boolean hasLogo() {
        return LOGO != null;
    }

    /** Logo PNG baytlari (kopya degil: salt okunur kullanin); yoksa null. */
    static byte[] logoPng() {
        return LOGO;
    }

    /**
     * Ust bant ici HTML'i. `brand` kacislanir (alt metin). Logo varsa gomulu gorsel, yoksa duz metin.
     */
    public static String headerHtml(String brand) {
        String name = HtmlUtils.htmlEscape(brand == null ? "" : brand, "UTF-8");
        String textStyle = "font-family:Arial,Helvetica,sans-serif;font-size:20px;font-weight:bold;color:#ffffff;";
        if (LOGO == null) {
            return "<span style=\"" + textStyle + "\">" + name + "</span>";
        }
        return "<img src=\"cid:" + LOGO_CID + "\" width=\"" + LOGO_WIDTH + "\" height=\"" + LOGO_HEIGHT
                + "\" alt=\"" + name + "\" style=\"display:inline-block;border:0;outline:none;text-decoration:none;"
                + "width:" + LOGO_WIDTH + "px;height:" + LOGO_HEIGHT + "px;line-height:" + LOGO_HEIGHT + "px;"
                + textStyle + "\">";
    }

    /** Tarayici onizlemesi icin (yonetim paneli): {@code cid:} kaynagini data: URI ile degistirir. Gonderimde KULLANILMAZ. */
    public static String forPreview(String html) {
        if (html == null || LOGO == null || !html.contains("cid:" + LOGO_CID)) {
            return html;
        }
        return html.replace("cid:" + LOGO_CID, "data:image/png;base64," + Base64.getEncoder().encodeToString(LOGO));
    }

    private static byte[] load() {
        try (var in = new ClassPathResource("mail-templates/logo.png").getInputStream()) {
            return in.readAllBytes();
        } catch (IOException e) {
            log.warn("Mail logosu okunamadi, yalniz metin basligi kullanilacak: {}", e.toString());
            return null;
        }
    }
}
