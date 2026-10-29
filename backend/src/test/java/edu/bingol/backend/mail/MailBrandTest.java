package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import jakarta.mail.Multipart;
import jakarta.mail.Part;
import jakarta.mail.Session;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import jakarta.mail.internet.MimePart;
import jakarta.mail.internet.MimeUtility;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;

/** Marka: gonderen adi (RFC 2047), gomulu logo (CID), HTML yapisi (tr/en/ar), duz metinde logo yok. */
class MailBrandTest {

    private static final Session SESSION = Session.getInstance(new Properties());

    private static MailProperties props(String from, String name) {
        return new MailProperties(true, from, name, 5000, 5, 20, false, "", 30, 300, "https://bukampus.com.tr", 180, "");
    }

    @SuppressWarnings("unchecked")
    private static MailTransport transport(MailProperties p) {
        return new MailTransport(mock(ObjectProvider.class), p);
    }

    private static MimeMessage build(MailProperties p, MailRenderer.Rendered r, MailCategory c) throws Exception {
        MimeMessage base = new MailTransport.DomainIdMimeMessage(SESSION, p.fromDomain());
        String unsub = c == MailCategory.ANNOUNCEMENT ? "https://bukampus.com.tr/u?t=1" : null;
        MimeMessage m = transport(p).buildMessage(base, "ali@bingol.edu.tr", r.subject(), r.text(), r.html(), null, c, unsub);
        m.saveChanges();
        return m;
    }

    private static MimeMessage buildCode(MailProperties p, Lang lang) throws Exception {
        return build(p, new MailRenderer().render(MailTemplate.VERIFICATION_CODE, lang,
                Map.of("code", "123456", "minutes", "10")), MailCategory.TRANSACTIONAL);
    }

    private static String raw(MimeMessage m) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        m.writeTo(out);
        return out.toString(StandardCharsets.UTF_8);
    }

    private static void collect(Part part, List<Part> out) throws Exception {
        out.add(part);
        if (part.isMimeType("multipart/*")) {
            Multipart mp = (Multipart) part.getContent();
            for (int i = 0; i < mp.getCount(); i++) {
                collect(mp.getBodyPart(i), out);
            }
        }
    }

    private static List<Part> parts(MimeMessage m) throws Exception {
        List<Part> all = new ArrayList<>();
        collect(m, all);
        return all;
    }

    private static List<Part> ofType(MimeMessage m, String mime) throws Exception {
        List<Part> hit = new ArrayList<>();
        for (Part p : parts(m)) {
            if (p.isMimeType(mime)) {
                hit.add(p);
            }
        }
        return hit;
    }

    // ---------- gonderen adi ----------

    @Test
    void fromHeaderCarriesBrandNameEncodedAsAsciiRfc2047() throws Exception {
        MimeMessage m = buildCode(props("noreply@bukampus.online", ""), Lang.TR);

        String fromLine = m.getHeader("From", null);
        assertThat(fromLine).matches("[\\x20-\\x7E]+"); // satirda ham 8-bit yok: RFC 2047 kodlu
        assertThat(fromLine).contains("=?UTF-8?").contains("<noreply@bukampus.online>");
        assertThat(MimeUtility.decodeText(fromLine)).isEqualTo("BÜ Kampüs <noreply@bukampus.online>");
        InternetAddress a = (InternetAddress) m.getFrom()[0];
        assertThat(a.getPersonal()).isEqualTo("BÜ Kampüs");
        assertThat(a.getAddress()).isEqualTo("noreply@bukampus.online");
    }

    @Test
    void fromGivenAsNameAndAddressDoesNotProduceDoubleName() throws Exception {
        // MAIL_FROM zaten "Ad <adres>"; MAIL_FROM_NAME bos: ad tek kez, adres temiz
        MailProperties p = props("BÜ Kampüs <noreply@bukampus.online>", "");
        assertThat(p.from()).isEqualTo("noreply@bukampus.online");
        assertThat(p.fromName()).isEqualTo("BÜ Kampüs");
        assertThat(p.fromDomain()).isEqualTo("bukampus.online");

        MimeMessage m = buildCode(p, Lang.EN);
        assertThat(MimeUtility.decodeText(m.getHeader("From", null))).isEqualTo("BÜ Kampüs <noreply@bukampus.online>");
        assertThat(m.getHeader("Message-ID", null)).endsWith("@bukampus.online>");
    }

    @Test
    void explicitFromNameWinsOverNameEmbeddedInFrom() {
        MailProperties p = props("\"Eski Ad\" <noreply@bukampus.online>", "BÜ Kampüs");
        assertThat(p.from()).isEqualTo("noreply@bukampus.online");
        assertThat(p.fromName()).isEqualTo("BÜ Kampüs");
        // yalniz gomulu ad varsa (tirnakli) o kullanilir
        assertThat(props("\"Kampüs Destek\" <x@bukampus.online>", " ").fromName()).isEqualTo("Kampüs Destek");
        assertThat(MailProperties.addressOf("A B <a@b.co>")).isEqualTo("a@b.co");
        assertThat(MailProperties.addressOf("a@b.co")).isEqualTo("a@b.co");
    }

    @Test
    void fromNameDefaultsToBrandAndCannotInjectHeaders() {
        assertThat(props("a@b.co", null).fromName()).isEqualTo("BÜ Kampüs");
        assertThat(props("a@b.co", "X\r\nBcc: z@z.co").fromName()).doesNotContain("\r").doesNotContain("\n");
    }

    // ---------- gomulu logo ----------

    @Test
    void logoIsSmallPngAndMessageEmbedsItAsInlineCid() throws Exception {
        assertThat(MailBrand.hasLogo()).isTrue();
        byte[] png = MailBrand.logoPng();
        assertThat(png.length).isLessThanOrEqualTo(20 * 1024);
        assertThat(png[0]).isEqualTo((byte) 0x89);
        assertThat(new String(png, 1, 3, StandardCharsets.US_ASCII)).isEqualTo("PNG");

        MimeMessage m = buildCode(props("noreply@bukampus.online", ""), Lang.TR);

        List<Part> images = ofType(m, "image/png");
        assertThat(images).hasSize(1);
        assertThat(((MimePart) images.get(0)).getContentID()).isEqualTo("<bu-logo>");
        assertThat(images.get(0).getDisposition()).isEqualToIgnoringCase(Part.INLINE);
        // yapi: multipart/related { multipart/alternative { text/plain, text/html }, image/png }
        assertThat(raw(m)).contains("multipart/related").contains("multipart/alternative");

        // duz metin parcasinda logo/gorsel yok; HTML parcasi cid ile ona baglanir
        List<Part> plains = ofType(m, "text/plain");
        List<Part> htmls = ofType(m, "text/html");
        assertThat(plains).hasSize(1);
        assertThat(htmls).hasSize(1);
        String plain = (String) plains.get(0).getContent();
        String html = (String) htmls.get(0).getContent();
        assertThat(plain).doesNotContain("cid:").doesNotContain("<");
        assertThat(html).contains("<img src=\"cid:bu-logo\"").contains("alt=\"BÜ Kampüs\"");
    }

    @Test
    void messageWithoutLogoReferenceGetsNoImagePart() throws Exception {
        MailProperties p = props("noreply@bukampus.online", "");
        MimeMessage m = transport(p).buildMessage(new MailTransport.DomainIdMimeMessage(SESSION, "bukampus.online"),
                "a@bingol.edu.tr", "Konu", "duz", "<p>destek yaniti</p>", null, MailCategory.TRANSACTIONAL, null);
        m.saveChanges();
        assertThat(ofType(m, "image/*")).isEmpty();
    }

    @Test
    void announcementKeepsUnsubscribeHeadersAndEmbedsLogo() throws Exception {
        MailRenderer.Rendered r = new MailRenderer().render(MailTemplate.ANNOUNCEMENT, Lang.TR,
                Map.of("heading", "Baslik", "message", "Mesaj"));
        MimeMessage m = build(props("noreply@bukampus.online", ""), r, MailCategory.ANNOUNCEMENT);

        assertThat(m.getHeader("List-Unsubscribe", null)).startsWith("<https://");
        assertThat(ofType(m, "image/png")).hasSize(1);
    }

    // ---------- HTML yapisi (tr/en/ar) ----------

    @Test
    void headerBandIsRedWithWhiteLogoAltTextOnBothLightAndDarkSchemes() {
        String html = new MailRenderer().render(MailTemplate.PASSWORD_RESET_CODE, Lang.EN,
                Map.of("code", "654321", "minutes", "15")).html();

        // bant rengi satir ici (acik) + koyu kipte sabit; alt metin beyaz+kalin -> gorsel yuklenmese de iki kipte okunur
        assertThat(html).contains("class=\"brandbar\"").contains("background-color:#C62A20")
                .contains(".brandbar { background-color: #C62A20 !important; }");
        assertThat(html).contains("color:#ffffff").contains("alt=\"BÜ Kampüs\"");
        assertThat(html).doesNotContain("{{").doesNotContain("}}");
    }

    @Test
    void arabicLayoutIsRtlAndBrandBarFollowsDirection() {
        String html = new MailRenderer().render(MailTemplate.VERIFICATION_CODE, Lang.AR,
                Map.of("code", "111222", "minutes", "10")).html();

        assertThat(html).contains("<html lang=\"ar\" dir=\"rtl\">");
        assertThat(html).contains("<td class=\"brandbar\" dir=\"rtl\"");
        assertThat(html).contains("dir=\"ltr\""); // kod kutusu LTR kalir
        assertThat(html).contains("111222");
    }

    @Test
    void previewSubstitutesDataUriWhileSendHtmlKeepsCid() {
        String html = new MailRenderer().render(MailTemplate.ACCOUNT_DELETED, Lang.TR, Map.of()).html();
        assertThat(html).contains("cid:bu-logo").doesNotContain("data:image");
        String preview = MailBrand.forPreview(html);
        assertThat(preview).contains("data:image/png;base64,").doesNotContain("cid:bu-logo");
        assertThat(MailBrand.forPreview(null)).isNull();
    }

    @Test
    void brandAltTextIsHtmlEscaped() {
        assertThat(MailBrand.headerHtml("A\"<b>")).contains("alt=\"A&quot;&lt;b&gt;\"").doesNotContain("<b>");
    }

    /** Elle inceleme icin onizleme dosyalari (tarayicida acilir; logo data URI ile) ve ham .eml yazar (target/). */
    @Test
    void writesPreviewFilesForManualInspection() throws Exception {
        Path dir = Path.of("target", "mail-preview");
        Files.createDirectories(dir);
        MailRenderer renderer = new MailRenderer();
        for (Lang lang : Lang.values()) {
            MailRenderer.Rendered r = renderer.render(MailTemplate.VERIFICATION_CODE, lang,
                    Map.of("code", "482915", "minutes", "10"));
            Files.writeString(dir.resolve("verification-" + lang.code() + ".html"), MailBrand.forPreview(r.html()),
                    StandardCharsets.UTF_8);
            Files.writeString(dir.resolve("verification-" + lang.code() + ".eml"),
                    raw(build(props("noreply@bukampus.online", ""), r, MailCategory.TRANSACTIONAL)),
                    StandardCharsets.UTF_8);
        }
        try (var s = Files.list(dir)) {
            assertThat(s.count()).isGreaterThanOrEqualTo(6);
        }
    }
}
