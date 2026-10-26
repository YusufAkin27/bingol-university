package edu.bingol.backend.mail;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class MailService {

    private static final Logger log = LoggerFactory.getLogger(MailService.class);

    /** SMTP ayari (spring.mail.host) yoksa bean olusmaz; bu yuzden istege bagli alinir. */
    private final ObjectProvider<JavaMailSender> sender;
    private final MailProperties props;
    private final I18n i18n;

    public MailService(ObjectProvider<JavaMailSender> sender, MailProperties props, I18n i18n) {
        this.i18n = i18n;
        this.sender = sender;
        this.props = props;
    }

    public void sendVerificationCode(String to, String code, int minutes, Lang lang) {
        if (!props.enabled()) {
            // Yalnizca gelistirme: e-posta kapaliyken kod log'a yazilir.
            log.warn("[DEV] {} icin dogrulama kodu: {}", to, code);
            return;
        }
        JavaMailSender mailSender = sender.getIfAvailable();
        if (mailSender == null) {
            log.error("app.mail.enabled=true ama spring.mail.host ayarli degil");
            throw mailUnavailable();
        }
        SimpleMailMessage m = new SimpleMailMessage();
        m.setFrom(props.from());
        m.setTo(to);
        m.setSubject(i18n.msg("mail.verification.subject", lang));
        m.setText(i18n.msg("mail.verification.body", lang, code, String.valueOf(minutes)));
        try {
            mailSender.send(m);
        } catch (Exception e) {
            log.error("E-posta gonderilemedi: {}", e.toString());
            throw mailUnavailable();
        }
    }

    /**
     * T27: duz metin + (kacisli) HTML alternatifli e-posta. Servis sozlesmesi: istisna sizdirmaz, basari bool doner.
     * E-posta kapaliyken govde log a yazilir (yalnizca gelistirme; dogrulama kodu/baglanti buradan okunur).
     */
    public boolean sendRich(String to, String subject, String plain, String html, String replyTo) {
        try {
            if (!props.enabled()) {
                // Tek satir: betikler kodu/baglantiyi log'dan grep ile okur
                log.warn("[DEV] {} icin e-posta: {} | {}", to, subject, plain.replace("\r", "").replace("\n", " / "));
                return true;
            }
            JavaMailSender mailSender = sender.getIfAvailable();
            if (mailSender == null) {
                log.error("app.mail.enabled=true ama spring.mail.host ayarli degil");
                return false;
            }
            jakarta.mail.internet.MimeMessage mm = mailSender.createMimeMessage();
            org.springframework.mail.javamail.MimeMessageHelper h =
                    new org.springframework.mail.javamail.MimeMessageHelper(mm, true, "UTF-8");
            h.setFrom(props.from());
            h.setTo(to);
            if (replyTo != null && !replyTo.isBlank()) {
                h.setReplyTo(replyTo);
            }
            h.setSubject(subject);
            h.setText(plain, html);
            mailSender.send(mm);
            return true;
        } catch (Exception e) {
            log.error("E-posta gonderilemedi: {}", e.toString());
            return false;
        }
    }

    private static ApiException mailUnavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                "Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.");
    }
}
