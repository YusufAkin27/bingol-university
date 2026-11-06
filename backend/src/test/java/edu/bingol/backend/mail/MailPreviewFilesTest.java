package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.campaign.CustomMailRenderer;
import edu.bingol.backend.mail.campaign.MailCustomTemplateVersionRepository;
import edu.bingol.backend.support.ticket.PublicSupportMailer;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.http.HttpStatus;

/**
 * Elle/Playwright ile inceleme icin TUM e-posta turlerini x tr/en/ar ornek verilerle HTML'e yazar (logo data: URI ile,
 * tarayicida acilir). Dizin: {@code -Dmail.preview.dir=...} ya da MAIL_PREVIEW_DIR; varsayilan target/mail-preview.
 * Gercek e-posta GONDERILMEZ. Dosya adi: {@code <tur>-<dil>.html}.
 */
class MailPreviewFilesTest {

    private static Path dir() throws IOException {
        String d = System.getProperty("mail.preview.dir", System.getenv("MAIL_PREVIEW_DIR"));
        Path p = Path.of(d == null || d.isBlank() ? "target/mail-preview" : d);
        Files.createDirectories(p);
        return p;
    }

    private static void write(Path dir, String name, String html) throws IOException {
        Files.writeString(dir.resolve(name + ".html"), MailBrand.forPreview(html), StandardCharsets.UTF_8);
    }

    @Test
    void writesEveryMailKindForEveryLanguage() throws Exception {
        Path dir = dir();
        MailRenderer renderer = new MailRenderer();
        int n = 0;
        for (MailTemplate t : MailTemplate.values()) {
            if (t == MailTemplate.CUSTOM) {
                continue;
            }
            for (Lang lang : Lang.values()) {
                MailRenderer.Rendered r = renderer.render(t, lang, MailBrandingTest.sample(t));
                String html = r.html();
                if (t == MailTemplate.ANNOUNCEMENT) {
                    html = UnsubscribeFooter.append(r, "https://bukampus.com.tr/api/public/mail/unsubscribe?token=abc", lang).html();
                }
                write(dir, t.key() + "-" + lang.code(), html);
                Files.writeString(dir.resolve(t.key() + "-" + lang.code() + ".txt"), r.text(), StandardCharsets.UTF_8);
                n++;
            }
        }

        // uzun icerikli stres ornekleri (tasma denetimi)
        String longName = "Muhammed Abdurrahman Çelikkıran-Yıldırımoğlu ".repeat(3).trim();
        String longUrl = "https://bukampus.com.tr/support/track?token=" + "AbC123xyz".repeat(24);
        for (Lang lang : Lang.values()) {
            MailRenderer.Rendered r = renderer.render(MailTemplate.ANNOUNCEMENT, lang, Map.of("heading",
                    "Çok uzun başlıklı duyuru: " + longName, "message",
                    "Uzun bağlantı: " + longUrl + "\nAşağıdaki satır çok uzun tek kelime: " + "Uzunkelime".repeat(18)));
            write(dir, "stress-announcement-" + lang.code(),
                    UnsubscribeFooter.append(r, "https://bukampus.com.tr/api/public/mail/unsubscribe?token=" + "t".repeat(180), lang).html());

            // destek: alindi / yanit / kodlu / sistem uyarisi
            String received = "Merhaba " + longName + ",\n\nDestek talebiniz alındı (#128). Durumu görmek, yanıtları okumak ve yeni "
                    + "mesaj yazmak için bu bağlantıyı kullanın:\n" + longUrl + "\n\nBağlantıyı kimseyle paylaşmayın.\n\nTalep özeti:\n"
                    + "Ders kayıt ekranında hata alıyorum, " + "çok ".repeat(40) + "yardım edebilir misiniz?";
            write(dir, "support-received-" + lang.code(), PublicSupportMailer.html("BÜ Kampüs – Destek talebiniz #128", received, lang,
                    MailLayout.text("mail.tpl.action.track", lang), null));
            String reply = "Merhaba Ali,\n\nDestek ekibimiz talebinizi yanıtladı:\n\nKaydınız güncellendi. Lütfen uygulamayı güncelleyip "
                    + "tekrar deneyin.\nSorun sürerse bu iletiye yanıt verebilirsiniz.\n\n---\nTalep #128: Ders kayıt ekranında hata\n\n"
                    + "Durumu görmek veya yeni mesaj yazmak için (bağlantıyı kimseyle paylaşmayın):\n" + longUrl;
            write(dir, "support-reply-" + lang.code(), PublicSupportMailer.html("BÜ Kampüs – Destek talebiniz #128", reply, lang,
                    MailLayout.text("mail.tpl.action.track", lang), null));
            String codeBody = "Merhaba,\n\nDestek talebinizi onaylamak için doğrulama kodunuz: 731904\n\nKod 10 dakika geçerlidir. "
                    + "Bu talebi siz oluşturmadıysanız bu e-postayı yok sayın.";
            write(dir, "support-code-" + lang.code(), PublicSupportMailer.html("BÜ Kampüs – Destek talebi doğrulama kodu", codeBody,
                    lang, null, "731904"));
        }
        write(dir, "system-alert-tr", MailLayout.page(Lang.TR, "Sistem uyarısı (CRIT): 2 gösterge",
                MailLayout.fromPlain("CRIT gostergeler: mailQueue, redis\nAyrinti: yonetim paneli > Sistem durumu.", null, null),
                MailLayout.Footer.AUTOMATED));

        // yonetici sablonu (eski kirmizi marka renkleri siyaha doner)
        CustomMailRenderer custom = new CustomMailRenderer(mock(MailCustomTemplateVersionRepository.class));
        CustomMailRenderer.Content c = new CustomMailRenderer.Content("Dönem sonu duyurusu {{ad}}",
                "<h2 style=\"color:#C62A20\">Final takvimi yayında</h2><p>Merhaba {{ad}}, final sınavları <b>18 Ocak</b>'ta başlıyor.</p>"
                        + "<ul><li>Sınav programı uygulamada</li><li>Kimlik kartınızı unutmayın</li></ul>"
                        + "<p><a style=\"background-color:#C62A20;color:#ffffff;padding:12px 20px;text-decoration:none\" "
                        + "href=\"https://bukampus.com.tr\">Programı aç</a></p>",
                "Merhaba {{ad}}");
        for (Lang lang : Lang.values()) {
            MailRenderer.Rendered r = custom.renderContent(c, lang, Map.of("ad", "Ali", "uygulamaUrl", "https://bukampus.com.tr"), "");
            write(dir, "custom-" + lang.code(),
                    UnsubscribeFooter.append(r, "https://bukampus.com.tr/api/public/mail/unsubscribe?token=abc", lang).html());
        }

        // abonelikten cik sayfasi (web sayfasi; ayni siyah-beyaz dil)
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/mail");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        MailUnsubscribeController ctl = new MailUnsubscribeController(null, null, null, null, new I18n(ms, null));
        for (Lang lang : Lang.values()) {
            write(dir, "unsubscribe-confirm-" + lang.code(), ctl.page(HttpStatus.OK, lang, "confirm", "tok").getBody());
            write(dir, "unsubscribe-done-" + lang.code(), ctl.page(HttpStatus.OK, lang, "done", null).getBody());
        }

        assertThat(n).isEqualTo((MailTemplate.values().length - 1) * 3);
        try (var s = Files.list(dir)) {
            assertThat(s.filter(p -> p.toString().endsWith(".html")).count()).isGreaterThanOrEqualTo(45);
        }
    }
}
