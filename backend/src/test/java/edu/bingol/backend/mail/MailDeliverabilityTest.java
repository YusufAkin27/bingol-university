package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import java.io.ByteArrayOutputStream;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mail.javamail.JavaMailSender;

/** Basliklar, kategori, abonelik jetonu, bounce siniflandirma, abonelik alt bilgisi. */
class MailDeliverabilityTest {

    private static final Session SESSION = Session.getInstance(new Properties());

    private static MailProperties props(String replyTo) {
        return new MailProperties(true, "no-reply@kampus.bingol.edu.tr", "BÜ Kampüs", 5000, 5, 20, false, replyTo, 30,
                300, "https://kampus.bingol.edu.tr", 180, "");
    }

    @SuppressWarnings("unchecked")
    private static MailTransport transport(MailProperties p) {
        return new MailTransport(mock(ObjectProvider.class), p);
    }

    private static String raw(MimeMessage m) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        m.writeTo(out);
        return out.toString(java.nio.charset.StandardCharsets.UTF_8);
    }

    private static MimeMessage build(MailProperties p, MailCategory c, String unsub, String replyTo) throws Exception {
        MimeMessage base = new MailTransport.DomainIdMimeMessage(SESSION, p.fromDomain());
        return transport(p).buildMessage(base, "a@bingol.edu.tr", "Konu", "duz metin", "<p>html</p>", replyTo, c, unsub);
    }

    @Test
    void transactionalHasAutoSubmittedAndNoListHeaders() throws Exception {
        MimeMessage m = build(props(""), MailCategory.TRANSACTIONAL, null, null);
        String raw = raw(m);

        assertThat(m.getHeader("Auto-Submitted", null)).isEqualTo("auto-generated");
        assertThat(m.getHeader("List-Unsubscribe")).isNull();
        assertThat(m.getHeader("Precedence")).isNull();
        assertThat(m.getHeader("X-Mailer")).isNull();
        assertThat(m.getSentDate()).isNotNull();
        assertThat(m.getHeader("Reply-To")).isNull();
        assertThat(m.getHeader("Message-ID")[0]).endsWith("@kampus.bingol.edu.tr>");
        assertThat(raw).contains("multipart/alternative").contains("text/plain").contains("text/html");
        assertThat(m.getFrom()[0].toString()).contains("no-reply@kampus.bingol.edu.tr");
    }

    @Test
    void announcementHasListUnsubscribeOneClickAndBulkPrecedence() throws Exception {
        String url = "https://kampus.bingol.edu.tr/api/public/mail/unsubscribe?token=t";
        MimeMessage m = build(props(""), MailCategory.ANNOUNCEMENT, url, null);

        assertThat(m.getHeader("List-Unsubscribe", null)).isEqualTo("<" + url + ">");
        assertThat(m.getHeader("List-Unsubscribe-Post", null)).isEqualTo("List-Unsubscribe=One-Click");
        assertThat(m.getHeader("Precedence", null)).isEqualTo("bulk");
        assertThat(m.getHeader("Auto-Submitted")).isNull();
    }

    @Test
    void announcementWithoutUnsubscribeUrlIsRefused() {
        assertThatThrownBy(() -> build(props(""), MailCategory.ANNOUNCEMENT, null, null))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void replyToComesFromSettingsUnlessExplicit() throws Exception {
        assertThat(build(props("destek@kampus.bingol.edu.tr"), MailCategory.TRANSACTIONAL, null, null)
                .getHeader("Reply-To", null)).contains("destek@kampus.bingol.edu.tr");
        assertThat(build(props("destek@kampus.bingol.edu.tr"), MailCategory.TRANSACTIONAL, null, "x@y.com")
                .getHeader("Reply-To", null)).contains("x@y.com");
    }

    @Test
    void categoryMapping() {
        assertThat(MailCategory.of(MailTemplate.ANNOUNCEMENT)).isEqualTo(MailCategory.ANNOUNCEMENT);
        assertThat(MailCategory.of(MailTemplate.VERIFICATION_CODE)).isEqualTo(MailCategory.TRANSACTIONAL);
        assertThat(MailCategory.of(MailTemplate.SECURITY_NEW_LOGIN)).isEqualTo(MailCategory.TRANSACTIONAL);
        assertThat(MailCategory.TRANSACTIONAL.priority()).isLessThan(MailCategory.ANNOUNCEMENT.priority());
    }

    @Test
    void unsubscribeTokenRoundTripTamperExpiryAndKey() {
        UnsubscribeTokens t = new UnsubscribeTokens(props(""), "jwt-secret-A");
        Instant now = Instant.now();
        String token = t.create("Ali@Bingol.edu.tr", now);

        assertThat(t.verify(token, now)).contains(MailSuppressionService.hash("ali@bingol.edu.tr"));
        assertThat(token).doesNotContain("ali");
        assertThat(t.verify(token + "x", now)).isEmpty();
        assertThat(t.verify("garbage", now)).isEmpty();
        assertThat(t.verify(null, now)).isEmpty();
        assertThat(t.verify(token, now.plus(Duration.ofDays(181)))).isEmpty();
        assertThat(new UnsubscribeTokens(props(""), "jwt-secret-B").verify(token, now)).isEmpty();
        // payload degistirilirse imza tutmaz
        String forged = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
                ("v1." + "0".repeat(64) + "." + (now.getEpochSecond() + 999999)).getBytes()) + token.substring(token.indexOf('.'));
        assertThat(t.verify(forged, now)).isEmpty();
    }

    @Test
    void unsubscribeUrlUsesBaseAndLangAndIsNullWithoutBase() {
        UnsubscribeTokens t = new UnsubscribeTokens(props(""), "s");
        String url = t.url("a@bingol.edu.tr", Lang.AR, Instant.now());
        assertThat(url).startsWith("https://kampus.bingol.edu.tr/api/public/mail/unsubscribe?token=").endsWith("&lang=ar");
        MailProperties noBase = new MailProperties(true, "a@b.com", "x", 1, 1, 1, false, "", 30, 300, "", 180, "");
        assertThat(new UnsubscribeTokens(noBase, "s").url("a@bingol.edu.tr", Lang.TR, Instant.now())).isNull();
    }

    @Test
    void bounceClassifierOnlyAcceptsExplicitPermanentRecipientErrors() {
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("550 5.1.1 User unknown"))).isTrue();
        assertThat(MailBounces.isPermanentRecipientFailure(new RuntimeException("x",
                new Exception("550-5.1.1 The email account does not exist")))).isTrue();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("553 5.1.3 bad recipient address syntax"))).isTrue();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("451 4.7.1 user unknown try later"))).isFalse();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("550 5.7.1 blocked as spam"))).isFalse();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("554 5.1.1 user unknown"))).isFalse();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("552 mailbox full"))).isFalse();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception("Connection timed out"))).isFalse();
        assertThat(MailBounces.isPermanentRecipientFailure(new Exception((String) null))).isFalse();
    }

    @Test
    void unsubscribeFooterAddsLinkWithHostDisplayToHtmlAndText() {
        var in = new MailRenderer.Rendered("s", "<html><body><p>x</p></body></html>", "duz");
        String url = "https://kampus.bingol.edu.tr/api/public/mail/unsubscribe?token=abc&lang=en";
        var out = UnsubscribeFooter.append(in, url, Lang.EN);

        assertThat(out.html()).contains("href=\"https://kampus.bingol.edu.tr/api/public/mail/unsubscribe?token=abc&amp;lang=en\"")
                .contains(">kampus.bingol.edu.tr</a>").contains("</p>\n</body>");
        assertThat(out.text()).contains("unsubscribe").contains(url);
        assertThat(Optional.of(out.subject())).contains("s");
    }

    @Test
    void i18nUnsubscribeKeysExistInAllLanguages() {
        for (Lang l : Lang.values()) {
            var rendered = UnsubscribeFooter.append(new MailRenderer.Rendered("s", "<body></body>", "t"), "https://a.b/x", l);
            assertThat(rendered.text()).doesNotContain("mail.tpl.unsubscribe.text");
        }
    }
}
