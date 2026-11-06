package edu.bingol.backend.mail;

import java.io.IOException;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.web.util.HtmlUtils;

/**
 * Marka ust bilgisi: serif "BU" amblemi + "BU Kampus" yazisi (siyah-beyaz, renkli bant yok).
 * <p>Iki gomulu gorsel vardir (ikisi de CID ile ek olarak gonderilir, {@link MailTransport}): acik zemin icin siyah glif
 * ({@code logo-light.png}) ve koyu zemin icin beyaz glif ({@code logo-dark.png}); 120x79 px (gorunen 40x26, 3x yogunluk,
 * her biri ~5 KB). Gmail data: URI'yi engeller, harici URL ise web dagitimina/CDN'e ve alicinin "gorselleri goster"
 * ayarina bagli olurdu. Varsayilan (acik) logo gorunur, koyu logo {@code display:none} ile gizlidir; yalniz
 * {@code prefers-color-scheme: dark} destekleyen istemcilerde (Apple Mail, iOS Mail, Outlook macOS/mobil) CSS ile
 * degisir. Gorseller yuklenmese bile yanindaki "BU Kampus" yazisi marka adini tasir. Logo dosyalari yoksa yalniz metin.
 */
public final class MailBrand {

    private static final Logger log = LoggerFactory.getLogger(MailBrand.class);

    /** HTML'deki {@code cid:} kimlikleri ve gomulu parcalarin Content-ID'leri. */
    public static final String LOGO_CID = "bu-logo";
    public static final String LOGO_DARK_CID = "bu-logo-dark";
    /** Gorunen boyut (px); dosyalar 3x (120x79) oldugundan retina'da keskin. */
    private static final int LOGO_WIDTH = 40;
    private static final int LOGO_HEIGHT = 26;

    private static final byte[] LOGO = load("mail-templates/logo-light.png");
    private static final byte[] LOGO_DARK = load("mail-templates/logo-dark.png");

    /** Yazi yigini: sistem sans (web-safe), kalin yok. */
    static final String FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

    private MailBrand() {
    }

    public static boolean hasLogo() {
        return LOGO != null && LOGO_DARK != null;
    }

    /** Acik zemin logosu (siyah glif) PNG baytlari; yoksa null. Salt okunur kullanin. */
    static byte[] logoPng() {
        return LOGO;
    }

    /** Koyu zemin logosu (beyaz glif) PNG baytlari; yoksa null. Salt okunur kullanin. */
    static byte[] logoDarkPng() {
        return LOGO_DARK;
    }

    /** Geriye uyumlu: soldan saga yerlesimli ust bilgi. */
    public static String headerHtml(String brand) {
        return headerHtml(brand, false);
    }

    /**
     * Ust bilgi ici HTML'i (tablo, Outlook uyumlu). `brand` kacislanir. RTL'de (Arapca) logo sagda, yazi solundadir;
     * bosluk yone gore ayri yazilir (Outlook mantiksal ozellikleri bilmez).
     */
    public static String headerHtml(String brand, boolean rtl) {
        String name = HtmlUtils.htmlEscape(brand == null ? "" : brand, "UTF-8");
        String dir = rtl ? "rtl" : "ltr";
        String gap = rtl ? "padding-left:12px;" : "padding-right:12px;";
        String wordmark = "<td class=\"txt\" valign=\"middle\" style=\"font-family:" + FONT
                + ";font-size:18px;font-weight:400;line-height:26px;letter-spacing:0.2px;color:#09090B;\">" + name + "</td>";
        String logo = "";
        if (hasLogo()) {
            String imgBase = "border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;width:"
                    + LOGO_WIDTH + "px;height:" + LOGO_HEIGHT + "px;";
            logo = "<td valign=\"middle\" style=\"" + gap + "\">"
                    + "<img class=\"logo-light\" src=\"cid:" + LOGO_CID + "\" width=\"" + LOGO_WIDTH + "\" height=\""
                    + LOGO_HEIGHT + "\" alt=\"" + name + "\" style=\"display:block;" + imgBase + "\">"
                    // koyu varyant: varsayilan gizli (Gmail/Outlook masaustu koyu medya sorgusunu bilmez)
                    + "<!--[if !mso]><!--><img class=\"logo-dark\" src=\"cid:" + LOGO_DARK_CID + "\" width=\""
                    + LOGO_WIDTH + "\" height=\"" + LOGO_HEIGHT + "\" alt=\"\" style=\"display:none;max-height:0;"
                    + "overflow:hidden;mso-hide:all;" + imgBase + "\"><!--<![endif]-->"
                    + "</td>";
        }
        return "<table role=\"presentation\" dir=\"" + dir + "\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\"><tr>"
                + logo + wordmark + "</tr></table>";
    }

    /** Tarayici onizlemesi icin (yonetim paneli): {@code cid:} kaynaklarini data: URI ile degistirir. Gonderimde KULLANILMAZ. */
    public static String forPreview(String html) {
        if (html == null || !hasLogo()) {
            return html;
        }
        String out = html;
        if (out.contains("cid:" + LOGO_CID + "\"")) {
            out = out.replace("cid:" + LOGO_CID + "\"", dataUri(LOGO) + "\"");
        }
        if (out.contains("cid:" + LOGO_DARK_CID + "\"")) {
            out = out.replace("cid:" + LOGO_DARK_CID + "\"", dataUri(LOGO_DARK) + "\"");
        }
        return out;
    }

    private static String dataUri(byte[] png) {
        return "data:image/png;base64," + Base64.getEncoder().encodeToString(png);
    }

    private static byte[] load(String path) {
        try (var in = new ClassPathResource(path).getInputStream()) {
            return in.readAllBytes();
        } catch (IOException e) {
            log.warn("Mail logosu okunamadi ({}), yalniz metin basligi kullanilacak: {}", path, e.toString());
            return null;
        }
    }
}
