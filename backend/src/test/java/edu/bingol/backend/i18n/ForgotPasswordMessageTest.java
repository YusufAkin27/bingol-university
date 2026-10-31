package edu.bingol.backend.i18n;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import org.junit.jupiter.api.Test;

/** A9-02 / T-123: sifre sifirlama yaniti e-postaya KOD gittigini soyler (baglanti degil). */
class ForgotPasswordMessageTest {

    private static final Path DIR = Paths.get("src/main/resources/i18n");

    private static String msg(String file) throws IOException {
        Properties p = new Properties();
        try (Reader r = new InputStreamReader(Files.newInputStream(DIR.resolve(file)), StandardCharsets.UTF_8)) {
            p.load(r);
        }
        return p.getProperty("msg.forgot.sent");
    }

    @Test
    void turkishTextSaysCodeNotLink() throws IOException {
        String tr = msg("messages.properties");
        assertThat(tr).isEqualTo("Hesap uygunsa e-posta adresinize \u015fifre s\u0131f\u0131rlama kodu g\u00f6nderildi.");
        assertThat(tr).doesNotContain("ba\u011flant\u0131");
    }

    @Test
    void englishAndArabicDoNotPromiseLink() throws IOException {
        assertThat(msg("messages_en.properties")).contains("code").doesNotContainIgnoringCase("link");
        assertThat(msg("messages_ar.properties")).doesNotContain("\u0631\u0627\u0628\u0637");
    }
}
