package edu.bingol.backend.support.ticket;

import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;
import org.springframework.web.util.HtmlUtils;

/**
 * Herkese acik talep e-postalari (tr/en/ar). Metin alicinin talep dilinde uretilir; kullanici ve yonetici metni
 * HTML'e KACISLI girer (ham HTML enjeksiyonu yok). Hicbir metot istisna sizdirmaz; basari bool doner.
 */
@Component
public class PublicSupportMailer {

    private static final Pattern URL = Pattern.compile("https?://[A-Za-z0-9._~:/?#\\[\\]@!$&()*+,;=%-]+");

    private final MailService mail;
    private final I18n i18n;
    private final SupportProperties props;
    private final AppSettingRepository settings;

    public PublicSupportMailer(MailService mail, I18n i18n, SupportProperties props, AppSettingRepository settings) {
        this.mail = mail;
        this.i18n = i18n;
        this.props = props;
        this.settings = settings;
    }

    public boolean sendCode(SupportTicket t, String code, int minutes) {
        Lang lang = Lang.of(t.getLang());
        String subject = i18n.msg("mail.support.code.subject", lang);
        String body = i18n.msg("mail.support.code.body", lang, safeName(t), code, String.valueOf(minutes));
        return send(t, lang, subject, body);
    }

    public boolean sendReceived(SupportTicket t, String firstMessage, String token) {
        Lang lang = Lang.of(t.getLang());
        String body = i18n.msg("mail.support.received.body", lang, safeName(t), String.valueOf(t.getId()),
                trackUrl(token), clip(firstMessage, 500));
        return send(t, lang, subject(t, lang), body);
    }

    public boolean sendReply(SupportTicket t, String reply, String firstMessage, String token) {
        Lang lang = Lang.of(t.getLang());
        String body = i18n.msg("mail.support.reply.body", lang, safeName(t), reply, String.valueOf(t.getId()),
                clip(firstMessage, 300), trackUrl(token));
        return send(t, lang, subject(t, lang), body);
    }

    String trackUrl(String token) {
        String base = props.trackBaseUrl() == null ? "" : props.trackBaseUrl().replaceAll("/+$", "");
        return base + "/support/track?token=" + token;
    }

    private String subject(SupportTicket t, Lang lang) {
        return i18n.msg("mail.support.subject", lang, String.valueOf(t.getId()));
    }

    private boolean send(SupportTicket t, Lang lang, String subject, String plain) {
        try {
            String replyTo = settings.findById("support_email").map(s -> s.getValue().trim()).orElse("");
            return mail.sendRich(t.getContactEmail(), subject, plain, html(plain, lang), replyTo);
        } catch (RuntimeException e) {
            return false;
        }
    }

    /** Duz metni kacislayip satir sonlarini ve baglantilari HTML'e cevirir. */
    static String html(String plain, Lang lang) {
        String escaped = HtmlUtils.htmlEscape(plain, "UTF-8");
        String linked = URL.matcher(escaped).replaceAll(m -> {
            String u = m.group().replace("&amp;", "&");
            // Kacislanmis metinde & zaten &amp;; href icin tekrar kacisla
            String href = HtmlUtils.htmlEscape(u, "UTF-8");
            return java.util.regex.Matcher.quoteReplacement("<a href=\"" + href + "\">" + href + "</a>");
        });
        String dir = lang == Lang.AR ? "rtl" : "ltr";
        return "<div dir=\"" + dir + "\" style=\"font-family:Arial,sans-serif;font-size:15px;line-height:1.5;color:#222\">"
                + linked.replace("\r\n", "\n").replace("\n", "<br>") + "</div>";
    }

    private static String safeName(SupportTicket t) {
        String n = t.getContactName() == null ? "" : t.getContactName();
        return n.replaceAll("[\\r\\n\\p{Cntrl}]", " ").trim();
    }

    private static String clip(String s, int max) {
        if (s == null) {
            return "";
        }
        String c = s.trim();
        return c.length() <= max ? c : c.substring(0, max) + "...";
    }
}
