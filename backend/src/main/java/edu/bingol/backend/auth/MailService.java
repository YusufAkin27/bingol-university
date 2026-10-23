package edu.bingol.backend.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class MailService {

    private static final Logger log = LoggerFactory.getLogger(MailService.class);

    private final JavaMailSender sender;
    private final boolean enabled;
    private final String from;

    public MailService(JavaMailSender sender,
                       @Value("${app.mail.enabled}") boolean enabled,
                       @Value("${app.mail.from}") String from) {
        this.sender = sender;
        this.enabled = enabled;
        this.from = from;
    }

    public void sendVerificationCode(String to, String code, int minutes) {
        if (!enabled) {
            // Yalnizca gelistirme: SMTP kapaliyken kod log'a yazilir.
            log.warn("[DEV] {} icin dogrulama kodu: {}", to, code);
            return;
        }
        SimpleMailMessage m = new SimpleMailMessage();
        m.setFrom(from);
        m.setTo(to);
        m.setSubject("Bingöl Üniversitesi - E-posta doğrulama kodu");
        m.setText("Doğrulama kodunuz: " + code + "\n\nKod " + minutes
                + " dakika geçerlidir. Bu işlemi siz yapmadıysanız bu e-postayı yok sayın.");
        try {
            sender.send(m);
        } catch (Exception e) {
            log.error("E-posta gonderilemedi: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                    "Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.");
        }
    }
}
