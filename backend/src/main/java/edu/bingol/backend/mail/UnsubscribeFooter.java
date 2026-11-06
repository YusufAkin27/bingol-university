package edu.bingol.backend.mail;

import edu.bingol.backend.i18n.Lang;
import java.net.URI;
import java.util.Locale;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.web.util.HtmlUtils;

/**
 * Duyuru maillerinin sonuna "abonelikten cik" baglantisi ekler (HTML + duz metin). Baglanti gosterim metni hedef
 * alan adidir (yaniltici baglanti sezgisini onlemek icin). Sablondan bagimsizdir (CUSTOM dahil).
 */
final class UnsubscribeFooter {

    private static final ResourceBundleMessageSource MESSAGES = new ResourceBundleMessageSource();

    static {
        MESSAGES.setBasename("i18n/mail");
        MESSAGES.setDefaultEncoding("UTF-8");
        MESSAGES.setFallbackToSystemLocale(false);
    }

    /** layout.html alt bilgi hucresindeki yer isareti. */
    static final String FOOTER_MARK = "<!--bu-footer-extra-->";

    private UnsubscribeFooter() {
    }

    static MailRenderer.Rendered append(MailRenderer.Rendered mail, String url, Lang lang) {
        String label = MESSAGES.getMessage("mail.tpl.unsubscribe.text", null, "Unsubscribe:", lang.locale());
        String host = host(url);
        String htmlPart = "<p class=\"muted\" style=\"margin:10px 0 0 0;font-size:13px;line-height:1.55;font-weight:400;"
                + "color:#52525B;\">" + HtmlUtils.htmlEscape(label, "UTF-8") + " <a class=\"link\" href=\""
                + HtmlUtils.htmlEscape(url, "UTF-8") + "\" style=\"color:#52525B;text-decoration:underline;\">"
                + HtmlUtils.htmlEscape(host, "UTF-8") + "</a></p>\n";
        String html = mail.html();
        // Yerlesimin alt bilgi hucresindeki isaret (kartin icinde); yoksa (yonetici yerlesimi vb.) govdeden once
        String newHtml;
        if (html.contains(FOOTER_MARK)) {
            newHtml = html.replace(FOOTER_MARK, htmlPart + FOOTER_MARK);
        } else {
            int body = html.toLowerCase(Locale.ROOT).lastIndexOf("</body>");
            newHtml = body >= 0 ? html.substring(0, body) + htmlPart + html.substring(body) : html + htmlPart;
        }
        String text = mail.text() + "\n" + label + " " + url + "\n";
        return new MailRenderer.Rendered(mail.subject(), newHtml, text);
    }

    static String host(String url) {
        try {
            String h = URI.create(url).getHost();
            return h == null ? url : h;
        } catch (IllegalArgumentException e) {
            return url;
        }
    }
}
