package edu.bingol.backend.mail;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
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

    public MailService(ObjectProvider<JavaMailSender> sender, MailProperties props) {
        this.sender = sender;
        this.props = props;
    }

    public void sendVerificationCode(String to, String code, int minutes) {
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
        m.setSubject("Bingöl Üniversitesi - E-posta doğrulama kodu");
        m.setText("Doğrulama kodunuz: " + code + "\n\nKod " + minutes
                + " dakika geçerlidir. Bu işlemi siz yapmadıysanız bu e-postayı yok sayın.");
        try {
            mailSender.send(m);
        } catch (Exception e) {
            log.error("E-posta gonderilemedi: {}", e.toString());
            throw mailUnavailable();
        }
    }

    private static ApiException mailUnavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                "Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.");
    }
}
