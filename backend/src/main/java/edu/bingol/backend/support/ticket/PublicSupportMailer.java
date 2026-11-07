package edu.bingol.backend.support.ticket;

import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.mail.MailDailyQuota;
import edu.bingol.backend.mail.MailLayout;
import edu.bingol.backend.mail.MailService;
import org.springframework.stereotype.Component;

/**
 * Herkese acik talep e-postalari (tr/en/ar). Metin alicinin talep dilinde uretilir; kullanici ve yonetici metni
 * HTML'e KACISLI girer (ham HTML enjeksiyonu yok). Hicbir metot istisna sizdirmaz; basari bool doner.
 */
@Component
public class PublicSupportMailer {

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

    /**
     * Talep acilirken kota ve IP korumasi: kimliksiz kod butcesi (SUPPORT) dolduysa 503, IP gunluk siniri asildiysa 429.
     * Talep kaydedilmeden ONCE cagrilir (kota harcayan her kimliksiz istek once buradan gecer).
     */
    public void requireQuota() {
        mail.requireCodeQuota(MailDailyQuota.CodeKind.SUPPORT);
    }

    /**
     * Dogrulama kodu postasi: DOGRULANMAMIS adrese gittigi icin konu ve govde SABITTIR; kullanici adi bu postaya
     * girmez (saldirgan kontrollu metinle kurumsal gondericiden oltalama onlenir). Kota/limit ihlali ApiException
     * olarak cagirana yayilir; diger hatalarda false doner.
     */
    public boolean sendCode(SupportTicket t, String code, int minutes) {
        Lang lang = Lang.of(t.getLang());
        String subject = i18n.msg("mail.support.code.subject", lang);
        String body = i18n.msg("mail.support.code.body", lang, code, String.valueOf(minutes));
        try {
            String replyTo = settings.findById("support_email").map(s -> s.getValue().trim()).orElse("");
            return mail.sendPublicCode(t.getContactEmail(), subject, plainWithTail(body, lang),
                    html(subject, body, lang, null, code), replyTo);
        } catch (ApiException e) {
            throw e;
        } catch (RuntimeException e) {
            return false;
        }
    }

    public boolean sendReceived(SupportTicket t, String firstMessage, String token) {
        Lang lang = Lang.of(t.getLang());
        String body = i18n.msg("mail.support.received.body", lang, safeName(t), String.valueOf(t.getId()),
                trackUrl(token), clip(firstMessage, 500));
        return send(t, lang, subject(t, lang), body, true);
    }

    public boolean sendReply(SupportTicket t, String reply, String firstMessage, String token) {
        Lang lang = Lang.of(t.getLang());
        String body = i18n.msg("mail.support.reply.body", lang, safeName(t), reply, String.valueOf(t.getId()),
                clip(firstMessage, 300), trackUrl(token));
        return send(t, lang, subject(t, lang), body, true);
    }

    String trackUrl(String token) {
        String base = props.trackBaseUrl() == null ? "" : props.trackBaseUrl().replaceAll("/+$", "");
        return base + "/support/track?token=" + token;
    }

    private String subject(SupportTicket t, Lang lang) {
        return i18n.msg("mail.support.subject", lang, String.valueOf(t.getId()));
    }

    private boolean send(SupportTicket t, Lang lang, String subject, String plain, boolean action) {
        try {
            String replyTo = settings.findById("support_email").map(s -> s.getValue().trim()).orElse("");
            String label = action ? MailLayout.text("mail.tpl.action.track", lang) : null;
            return mail.sendRich(t.getContactEmail(), subject, plainWithTail(plain, lang),
                    html(subject, plain, lang, label, null), replyTo);
        } catch (RuntimeException e) {
            return false;
        }
    }

    /**
     * Duz metni marka cercevesine koyar (siyah-beyaz yerlesim): bos satirla ayrilan bloklar paragraf, tek basina
     * baglanti satiri `actionLabel` varsa birincil dugme, `code` varsa kod kutusu. Metin KACISLI girer (ham HTML
     * enjeksiyonu yok); baslik konudan ("BÜ Kampüs – " oneki atilarak) turetilir.
     */
    public static String html(String subject, String plain, Lang lang, String actionLabel, String code) {
        String title = subject == null ? "" : subject.replaceFirst("^BÜ Kampüs\\s*[–-]\\s*", "");
        return MailLayout.page(lang, title, MailLayout.fromPlain(plain, actionLabel, code), MailLayout.Footer.SUPPORT);
    }

    /** Duz metin alternatifine marka adi ve alt bilgi eklenir. */
    public static String plainWithTail(String plain, Lang lang) {
        return MailLayout.brand(lang) + "\n\n" + plain.strip() + "\n\n"
                + MailLayout.plainTail(lang, MailLayout.Footer.SUPPORT);
    }


    /**
     * Ad yalnız harf/rakam/boşluk/nokta/kesme/tire ile sınırlanır; '@', '/', ':' gibi URL ve adres karakterleri
     * düşürülür (ad HTML'de bağlantılaşmasın, oltalama metni taşımasın). En fazla 60 karakter.
     */
    static String safeName(SupportTicket t) {
        String n = t.getContactName() == null ? "" : t.getContactName();
        n = n.replaceAll("[^\\p{L}\\p{M}\\p{N} .'\\-]", " ").replaceAll("\\s+", " ").trim();
        return n.length() > 60 ? n.substring(0, 60).trim() : n;
    }

    private static String clip(String s, int max) {
        if (s == null) {
            return "";
        }
        String c = s.trim();
        return c.length() <= max ? c : c.substring(0, max) + "...";
    }
}
