package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.i18n.Lang;
import java.util.Map;
import org.junit.jupiter.api.Test;

class MailRendererTest {

    private final MailRenderer renderer = new MailRenderer();

    @Test
    void verificationContainsCodeMinutesAndBrand() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.VERIFICATION_CODE, Lang.TR,
                Map.of("code", "123456", "minutes", "10"));

        assertThat(r.html()).contains("123456").contains("10 dakika").contains("#C62A20").contains("dir=\"ltr\"");
        assertThat(r.text()).contains("123456").contains("10 dakika");
        assertThat(r.subject()).contains("doğrulama");
    }

    @Test
    void arabicIsRightToLeft() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.ACCOUNT_DELETED, Lang.AR, Map.of());

        assertThat(r.html()).contains("<html lang=\"ar\" dir=\"rtl\">");
    }

    @Test
    void englishUsesEnglishTexts() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.PASSWORD_RESET_CODE, Lang.EN,
                Map.of("code", "654321", "minutes", "15"));

        assertThat(r.subject()).isEqualTo("BÜ Kampüs - Password reset code");
        assertThat(r.html()).contains("<html lang=\"en\" dir=\"ltr\">");
    }

    @Test
    void variablesAreHtmlEscaped() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.ANNOUNCEMENT, Lang.TR,
                Map.of("heading", "<b>Baslik</b>", "message", "<script>alert(1)</script>"));

        assertThat(r.html()).doesNotContain("<script>").doesNotContain("<b>Baslik</b>")
                .contains("&lt;script&gt;alert(1)&lt;/script&gt;");
        assertThat(r.text()).contains("<script>alert(1)</script>");
    }

    @Test
    void subjectCannotContainLineBreaks() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.ANNOUNCEMENT, Lang.TR,
                Map.of("heading", "Konu\r\nBcc: kurban@example.com", "message", "x"));

        assertThat(r.subject()).doesNotContain("\r").doesNotContain("\n");
    }

    @Test
    void fillLeavesUnknownPlaceholdersEmptyAndKeepsDollarSigns() {
        String out = MailRenderer.fill("a {{x}} b {{y}} c {{{z}}}", Map.of("x", "$1&", "z", "<i>"),
                MailRenderer::escape);

        assertThat(out).isEqualTo("a $1&amp; b  c <i>");
    }
}
