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

    private UnsubscribeFooter() {
    }

    static MailRenderer.Rendered append(MailRenderer.Rendered mail, String url, Lang lang) {
        String label = MESSAGES.getMessage("mail.tpl.unsubscribe.text", null, "Unsubscribe:", lang.locale());
        String host = host(url);
        String htmlPart = "<p class=\"muted\" style=\"margin:0;padding:8px 28px 24px 28px;font-family:Arial,Helvetica,sans-serif;"
                + "font-size:12px;line-height:1.5;color:#6b6f80;\">" + HtmlUtils.htmlEscape(label, "UTF-8") + " <a href=\""
                + HtmlUtils.htmlEscape(url, "UTF-8") + "\" style=\"color:#6b6f80;\">" + HtmlUtils.htmlEscape(host, "UTF-8")
                + "</a></p>\n";
        String html = mail.html();
        int body = html.toLowerCase(Locale.ROOT).lastIndexOf("</body>");
        String newHtml = body >= 0 ? html.substring(0, body) + htmlPart + html.substring(body) : html + htmlPart;
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
