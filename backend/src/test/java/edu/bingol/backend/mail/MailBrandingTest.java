package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.campaign.CustomMailRenderer;
import edu.bingol.backend.mail.campaign.MailCustomTemplateVersionRepository;
import edu.bingol.backend.support.ticket.PublicSupportMailer;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/**
 * Siyah-beyaz marka cercevesi: her sablon x dil icin HTML iyi bicimli, gomulu logo + alt var, yer tutucu kalmamis,
 * duz metin dolu ve markali, koyu mod medya sorgusu var, eski kirmizi marka renkleri/kalin yazi/gradient/golge YOK.
 */
class MailBrandingTest {

    private static final Pattern RED = Pattern.compile("(?i)#(C62A20|F73A2E|ED211B)");
    private static final Pattern BOLD = Pattern.compile("(?i)font-weight\\s*:\\s*(bold|bolder|[5-9]00)");
    private static final Set<String> VOID = Set.of("meta", "img", "br", "hr", "link", "input", "col", "base");

    private final MailRenderer renderer = new MailRenderer();

    /** Her sablon icin ornek degiskenler (kod, sure, cihaz, zaman, mesaj, baslik). */
    static Map<String, String> sample(MailTemplate t) {
        return switch (t) {
            case VERIFICATION_CODE, PASSWORD_RESET_CODE, TWO_FACTOR_CODE, SUPPORT_CODE ->
                    Map.of("code", "482915", "minutes", "10");
            case SECURITY_NEW_LOGIN -> Map.of("device", "iPhone 15 (iOS 18)", "time", "06.11.2026 14:32");
            case SECURITY_PASSWORD_CHANGED -> Map.of("time", "06.11.2026 14:32");
            case SECURITY_TWO_FACTOR_NOTICE -> Map.of("message",
                    "Hesabınızda 06.11.2026 14:32 tarihinde iki faktörlü doğrulama açıldı.\nBunu siz yapmadıysanız şifrenizi hemen değiştirin.");
            case ANNOUNCEMENT -> Map.of("heading", "Bahar şenliği programı açıklandı",
                    "message", "Şenlik 12 Mayıs'ta kampüs meydanında başlıyor.\nProgram ve kayıt bilgileri uygulamada.");
            default -> Map.of();
        };
    }

    @Test
    void everyTemplateInEveryLanguageIsOnBrand() {
        int checked = 0;
        for (MailTemplate t : MailTemplate.values()) {
            if (t == MailTemplate.CUSTOM) {
                continue;
            }
            for (Lang lang : Lang.values()) {
                String id = t + "/" + lang.code();
                MailRenderer.Rendered r = renderer.render(t, lang, sample(t));
                assertOnBrand(id, r.html(), r.text(), lang);
                assertThat(r.subject()).as(id).isNotBlank().doesNotContain("mail.tpl.").doesNotContain("{{");
                if (t.isCode()) {
                    assertThat(r.html()).as(id).contains("class=\"codebox\"").contains("482915");
                    assertThat(r.text()).as(id).contains("482915");
                }
                checked++;
            }
        }
        assertThat(checked).isEqualTo((MailTemplate.values().length - 1) * 3);
    }

    @Test
    void lastParagraphOfNonCodeMailsBecomesSecurityNote() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.SECURITY_PASSWORD_CHANGED, Lang.TR,
                Map.of("time", "06.11.2026 14:32"));
        assertThat(r.html()).contains("class=\"note\"").contains("destek ekibiyle iletişime geçin");
        // duyuruda (serbest metin) not yok
        assertThat(renderer.render(MailTemplate.ANNOUNCEMENT, Lang.TR, sample(MailTemplate.ANNOUNCEMENT)).html())
                .doesNotContain("class=\"note\"");
    }

    @Test
    void supportMailsAreOnBrandAndEscapeEverything() {
        String longUrl = "https://bukampus.com.tr/support/track?token=" + "a".repeat(200);
        String plain = "Merhaba <b>Ali</b>,\n\nTalebiniz alındı (#12). Bağlantı:\n" + longUrl
                + "\n\nBağlantıyı kimseyle paylaşmayın.\n\n---\nTalep özeti:\n<script>alert(1)</script> https://x.test/a?b=1&c=2.";
        for (Lang lang : Lang.values()) {
            String html = PublicSupportMailer.html("BÜ Kampüs – Destek talebiniz #12", plain, lang, "Talebimi görüntüle", null);
            String text = PublicSupportMailer.plainWithTail(plain, lang);
            assertOnBrand("support/" + lang.code(), html, text, lang);
            assertThat(html).contains("class=\"btn-a\"").contains("word-break:break-all").doesNotContain("<script")
                    .contains("&lt;script&gt;").contains("href=\"https://x.test/a?b=1&amp;c=2\"");
            // baslik: marka oneki atilir
            assertThat(html).contains("<h1 class=\"txt\"").contains(">Destek talebiniz #12</h1>");
        }
        // kodlu destek postasi: kod blogun sonundan ayrilip kutuda gosterilir
        String codeHtml = PublicSupportMailer.html("BÜ Kampüs – Destek talebi doğrulama kodu",
                "Merhaba,\n\nDestek talebinizi onaylamak için doğrulama kodunuz: 123456\n\nKod 10 dakika geçerlidir.",
                Lang.TR, null, "123456");
        assertThat(codeHtml).contains("class=\"codebox\"").doesNotContain("kodunuz: 123456");
    }

    @Test
    void customAdminTemplatesGetTheFrameAndLegacyRedIsNeutralised() {
        CustomMailRenderer custom = new CustomMailRenderer(mock(MailCustomTemplateVersionRepository.class));
        CustomMailRenderer.Content c = new CustomMailRenderer.Content("Duyuru {{ad}}",
                "<p style=\"color:#C62A20\">Selam {{ad}}</p><a style=\"background:#c62a20;color:#fff\" href=\"https://x.test\">Aç</a>",
                "Selam {{ad}}");
        for (Lang lang : Lang.values()) {
            MailRenderer.Rendered r = custom.renderContent(c, lang,
                    Map.of("ad", "Ali", "uygulamaUrl", "https://app.test"), "");
            assertOnBrand("custom/" + lang.code(), r.html(), r.text(), lang);
        }
    }

    @Test
    void announcementUnsubscribeLineSitsInsideTheCardFooter() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.ANNOUNCEMENT, Lang.EN, sample(MailTemplate.ANNOUNCEMENT));
        MailRenderer.Rendered withUnsub = UnsubscribeFooter.append(r, "https://bukampus.com.tr/u?t=1&x=2", Lang.EN);
        String html = withUnsub.html();
        int link = html.indexOf("bukampus.com.tr/u?t=1&amp;x=2");
        assertThat(link).isPositive();
        assertThat(link).isGreaterThan(html.indexOf("class=\"hair\"")).isLessThan(html.lastIndexOf("</table>"));
        assertThat(withUnsub.text()).contains("https://bukampus.com.tr/u?t=1&x=2");
    }

    @Test
    void layoutHasNoRedGradientShadowOrBoldAndLogosAreSmall() {
        MailRenderer.Rendered r = renderer.render(MailTemplate.VERIFICATION_CODE, Lang.TR, sample(MailTemplate.VERIFICATION_CODE));
        assertThat(r.html()).doesNotContainIgnoringCase("gradient").doesNotContainIgnoringCase("box-shadow")
                .doesNotContainIgnoringCase("text-shadow").doesNotContain("<b>").doesNotContain("<strong>");
        assertThat(MailBrand.logoPng().length).isLessThan(12 * 1024);
        assertThat(MailBrand.logoDarkPng().length).isLessThan(12 * 1024);
    }

    // ---------- ortak denetim ----------

    static void assertOnBrand(String id, String html, String text, Lang lang) {
        assertThat(html).as(id).doesNotContain("{{").doesNotContain("}}").doesNotContain("${").doesNotContain("mail.tpl.");
        assertThat(html).as(id).contains("src=\"cid:" + MailBrand.LOGO_CID + "\"").contains("src=\"cid:" + MailBrand.LOGO_DARK_CID + "\"")
                .contains("alt=\"BÜ Kampüs\"").contains("class=\"logo-light\"").contains("class=\"logo-dark\"");
        assertThat(html).as(id).contains("@media (prefers-color-scheme: dark)").contains("name=\"color-scheme\"")
                .contains("name=\"supported-color-schemes\"").contains("#09090B").contains("#141416")
                .contains("#303034").contains("#FAFAFA");
        assertThat(html).as(id).contains("<html lang=\"" + lang.code() + "\" dir=\"" + (lang == Lang.AR ? "rtl" : "ltr") + "\">")
                .contains("align=\"" + (lang == Lang.AR ? "right" : "left") + "\"");
        assertThat(html).as(id).contains("width=\"600\"").contains("max-width:600px").contains("border-radius:12px");
        assertThat(html).as(id).contains("<!--bu-footer-extra-->").contains("BÜ Kampüs");
        assertThat(RED.matcher(html).find()).as(id + " eski kirmizi marka rengi").isFalse();
        Matcher b = BOLD.matcher(html);
        assertThat(b.find()).as(id + " kalin yazi").isFalse();
        assertThat(html.toLowerCase()).as(id).doesNotContain("gradient").doesNotContain("box-shadow");
        assertBalanced(id, html);

        assertThat(text).as(id).isNotBlank().startsWith("BÜ Kampüs").contains("\n--\n").contains("BÜ Kampüs · ")
                .doesNotContain("{{").doesNotContain("mail.tpl.");
    }

    /** Kapanmayan/yanlis kapanan etiket yok (yorumlar, stil ve DOCTYPE atlanir; void etiketler kapanmaz). */
    static void assertBalanced(String id, String html) {
        String s = html.replaceAll("(?s)<!--.*?-->", "").replaceAll("(?s)<style.*?</style>", "").replaceAll("(?i)<!doctype[^>]*>", "");
        Matcher m = Pattern.compile("<(/?)([a-zA-Z][a-zA-Z0-9]*)\\b[^>]*?(/?)>").matcher(s);
        Deque<String> stack = new ArrayDeque<>();
        while (m.find()) {
            String name = m.group(2).toLowerCase();
            boolean close = !m.group(1).isEmpty();
            if (VOID.contains(name) || !m.group(3).isEmpty()) {
                continue;
            }
            if (!close) {
                stack.push(name);
            } else {
                assertThat(stack).as(id + " kapanis </" + name + "> icin acik etiket yok").isNotEmpty();
                String open = stack.pop();
                assertThat(name).as(id + " yanlis kapanis").isEqualTo(open);
            }
        }
        assertThat(stack).as(id + " kapanmayan etiketler").isEmpty();
    }
}
