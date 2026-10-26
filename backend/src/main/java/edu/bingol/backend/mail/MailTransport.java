package edu.bingol.backend.mail;

import edu.bingol.backend.config.MailProperties;
import jakarta.mail.internet.MimeMessage;
import java.io.UnsupportedEncodingException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;

/** SMTP tasiyicisi: tek bir e-postayi (HTML + duz metin) gonderir. Hata durumunda istisna firlatir. */
@Component
public class MailTransport {

    private static final Logger log = LoggerFactory.getLogger(MailTransport.class);

    /** SMTP ayari (spring.mail.host) yoksa bean olusmaz; bu yuzden istege bagli alinir. */
    private final ObjectProvider<JavaMailSender> sender;
    private final MailProperties props;

    public MailTransport(ObjectProvider<JavaMailSender> sender, MailProperties props) {
        this.sender = sender;
        this.props = props;
    }

    public void send(String to, String subject, String plain, String html, String replyTo) throws Exception {
        JavaMailSender mailSender = sender.getIfAvailable();
        if (mailSender == null) {
            throw new IllegalStateException("app.mail.enabled=true ama spring.mail.host ayarli degil");
        }
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        applyHeaders(helper, to, subject, replyTo);
        helper.setText(plain, html);
        mailSender.send(message);
    }

    private void applyHeaders(MimeMessageHelper helper, String to, String subject, String replyTo)
            throws jakarta.mail.MessagingException, UnsupportedEncodingException {
        helper.setFrom(props.from(), props.fromName());
        helper.setTo(to);
        if (replyTo != null && !replyTo.isBlank()) {
            helper.setReplyTo(replyTo);
        }
        helper.setSubject(subject);
    }

    /** Yalnizca gelistirme (app.mail.enabled=false): gonderim yerine icerik log'a yazilir. */
    public void logInsteadOfSending(String to, String subject, String plain) {
        log.warn("[DEV] {} icin e-posta: {} | {}", to, subject, plain.replace("\r", "").replace("\n", " / "));
    }
}
