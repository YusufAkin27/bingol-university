package edu.bingol.backend.mail;

import edu.bingol.backend.config.MailProperties;
import jakarta.mail.MessagingException;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import java.io.UnsupportedEncodingException;
import java.util.Date;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;

/**
 * SMTP tasiyicisi: tek bir e-postayi (multipart/alternative: duz metin + HTML) gonderir. Hata durumunda istisna
 * firlatir. Teslim edilebilirlik basliklari: Message-ID (kendi alan adimizla), Date, Reply-To, Auto-Submitted
 * (islemsel), Precedence + List-Unsubscribe(-Post, RFC 8058) (yalniz duyuru). X-Mailer eklenmez.
 */
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

    /** Islemsel gonderim (geriye uyumlu imza). */
    public void send(String to, String subject, String plain, String html, String replyTo) throws Exception {
        send(to, subject, plain, html, replyTo, MailCategory.TRANSACTIONAL, null);
    }

    /**
     * @param unsubscribeUrl duyuru turunde zorunlu (https adresi); islemsel turde yok sayilir
     */
    public void send(String to, String subject, String plain, String html, String replyTo, MailCategory category,
                     String unsubscribeUrl) throws Exception {
        JavaMailSender mailSender = sender.getIfAvailable();
        if (mailSender == null) {
            throw new IllegalStateException("app.mail.enabled=true ama spring.mail.host ayarli degil");
        }
        MimeMessage base = newMessage(mailSender);
        MimeMessage message = buildMessage(base, to, subject, plain, html, replyTo, category, unsubscribeUrl);
        mailSender.send(message);
    }

    private MimeMessage newMessage(JavaMailSender mailSender) {
        if (mailSender instanceof JavaMailSenderImpl impl) {
            return new DomainIdMimeMessage(impl.getSession(), props.fromDomain());
        }
        return mailSender.createMimeMessage();
    }

    /** Basliklari ve govdeyi kurar (test edilebilir: ag erisimi yok). */
    MimeMessage buildMessage(MimeMessage message, String to, String subject, String plain, String html,
                             String replyTo, MailCategory category, String unsubscribeUrl) throws Exception {
        if (category == MailCategory.ANNOUNCEMENT && (unsubscribeUrl == null || !unsubscribeUrl.startsWith("https://")
                && !unsubscribeUrl.startsWith("http://"))) {
            throw new IllegalStateException("Duyuru e-postasi icin abonelikten cikma baglantisi zorunlu");
        }
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        applyHeaders(helper, to, subject, replyTo);
        helper.setText(plain, html);
        if (category == MailCategory.ANNOUNCEMENT) {
            message.setHeader("Precedence", "bulk");
            message.setHeader("List-Unsubscribe", "<" + unsubscribeUrl + ">");
            message.setHeader("List-Unsubscribe-Post", "List-Unsubscribe=One-Click");
        } else {
            message.setHeader("Auto-Submitted", "auto-generated");
            message.setHeader("X-Auto-Response-Suppress", "All");
        }
        return message;
    }

    private void applyHeaders(MimeMessageHelper helper, String to, String subject, String replyTo)
            throws MessagingException, UnsupportedEncodingException {
        helper.setFrom(props.from(), props.fromName());
        helper.setTo(to);
        String reply = replyTo != null && !replyTo.isBlank() ? replyTo : props.replyTo();
        if (reply != null && !reply.isBlank()) {
            helper.setReplyTo(reply);
        }
        helper.setSubject(subject);
        helper.setSentDate(new Date());
    }

    /** Yalnizca gelistirme (app.mail.enabled=false): gonderim yerine icerik log'a yazilir. */
    public void logInsteadOfSending(String to, String subject, String plain) {
        log.warn("[DEV] {} icin e-posta: {} | {}", to, subject, plain.replace("\r", "").replace("\n", " / "));
    }

    /**
     * Message-ID'yi kendi alan adimizla uretir (varsayilan sunucu ana makine adini sizdirir ve DKIM/DMARC
     * hizalamasina yardim etmez). Jakarta Mail her kayitta updateMessageID'yi cagirir; burada gecersiz kilinir.
     */
    static final class DomainIdMimeMessage extends MimeMessage {

        private final String domain;

        DomainIdMimeMessage(Session session, String domain) {
            super(session);
            this.domain = domain == null || domain.isBlank() ? "localhost" : domain;
        }

        @Override
        protected void updateMessageID() throws MessagingException {
            setHeader("Message-ID", "<" + UUID.randomUUID() + "@" + domain + ">");
        }
    }
}
