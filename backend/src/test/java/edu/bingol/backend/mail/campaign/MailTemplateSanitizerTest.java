package edu.bingol.backend.mail.campaign;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import edu.bingol.backend.common.ApiException;
import org.junit.jupiter.api.Test;

class MailTemplateSanitizerTest {

    @Test
    void scriptIframeFormAndEventHandlersAreRemoved() {
        String html = MailTemplateSanitizer.cleanHtml("<p onclick=\"evil()\">Merhaba</p><script>alert(1)</script>"
                + "<iframe src=\"https://x.test\"></iframe><form action=\"https://x.test\"><input name=a></form>"
                + "<img src=\"https://cdn.test/a.png\" onerror=\"evil()\">");
        assertThat(html).contains("Merhaba").contains("<img");
        assertThat(html.toLowerCase()).doesNotContain("script").doesNotContain("alert(1)").doesNotContain("iframe")
                .doesNotContain("<form").doesNotContain("<input").doesNotContain("onclick").doesNotContain("onerror");
    }

    @Test
    void onlyHttpsLinksAndImagesSurvive() {
        String html = MailTemplateSanitizer.cleanHtml("<a href=\"javascript:alert(1)\">a</a><a href=\"http://insecure.test\">b</a>"
                + "<a href=\"https://ok.test/x?a=1&b=2\">c</a><img src=\"http://insecure.test/i.png\"><img src=\"data:image/png;base64,AAAA\">");
        assertThat(html).doesNotContain("javascript:").doesNotContain("http://").doesNotContain("data:");
        assertThat(html).contains("https://ok.test/x?a=1&amp;b=2").contains("rel=\"noopener noreferrer nofollow\"");
    }

    @Test
    void dangerousInlineStylesAreDroppedSafeOnesKept() {
        String html = MailTemplateSanitizer.cleanHtml("<p style=\"color:red;font-size:18px\">ok</p>"
                + "<p style=\"width:expression(alert(1))\">x</p><p style=\"background:url(javascript:alert(1))\">y</p>"
                + "<p style=\"background:url(http://t.test/p.gif)\">z</p><p style=\"background:url(https://t.test/p.gif)\">w</p>");
        assertThat(html).contains("color:red;font-size:18px").doesNotContain("expression").doesNotContain("javascript")
                .doesNotContain("http://").contains("https://t.test/p.gif");
    }

    @Test
    void placeholdersSurviveIncludingInsideHrefAndAreNormalized() {
        String html = MailTemplateSanitizer.cleanHtml("<p>Merhaba {{ ad }}!</p><a href=\"{{uygulamaUrl}}\">Ac</a>"
                + "<a href=\"{{abonelikCikUrl}}\">Cik</a>");
        assertThat(html).contains("Merhaba {{ad}}!").contains("href=\"{{uygulamaUrl}}\"").contains("href=\"{{abonelikCikUrl}}\"");
        assertThat(html).doesNotContain("mv.invalid");
    }

    @Test
    void unknownVariableTripleBracesAndStrayBracesAreRejected() {
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanHtml("<p>{{telefon}}</p>")).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("MAIL_TEMPLATE_VARIABLE_UNKNOWN"));
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanHtml("<p>{{{ad}}}</p>")).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("MAIL_TEMPLATE_INVALID"));
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanHtml("<p>{{ad</p>")).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("MAIL_TEMPLATE_INVALID"));
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanSubject("Selam {{x}}")).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("MAIL_TEMPLATE_VARIABLE_UNKNOWN"));
    }

    @Test
    void emptyOrScriptOnlyBodyIsInvalid() {
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanHtml("   ")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanHtml("<script>alert(1)</script>")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanHtml("x".repeat(MailTemplateSanitizer.MAX_HTML + 1)))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void subjectIsSingleLineAndLimited() {
        assertThat(MailTemplateSanitizer.cleanSubject("Konu\r\nBcc: x@y.z")).doesNotContain("\n").doesNotContain("\r");
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanSubject("a".repeat(201))).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> MailTemplateSanitizer.cleanSubject("  ")).isInstanceOf(ApiException.class);
    }

    @Test
    void plainTextIsGeneratedFromHtmlWithLinks() {
        String html = MailTemplateSanitizer.cleanHtml("<h1>Baslik</h1><p>Satir bir<br>Satir iki</p>"
                + "<ul><li>Bir</li><li>Iki</li></ul><a href=\"https://ok.test\">Site</a>");
        String text = MailTemplateSanitizer.cleanText(null, html);
        assertThat(text).contains("Baslik").contains("Satir bir\nSatir iki").contains("- Bir").contains("Site (https://ok.test)");
        assertThat(text).doesNotContain("<").doesNotContain(">");
        // yoneticinin verdigi duz metin korunur
        assertThat(MailTemplateSanitizer.cleanText("Elle yazilan {{ad}}", html)).isEqualTo("Elle yazilan {{ad}}");
    }
}
