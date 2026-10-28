package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;

/** V481 (yayinci ayarlari) betiginin yapi kontrolu; PostgreSQL'e ozel oldugundan H2'de calistirilmaz. */
class LegalMigrationV481FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V481__legal_controller_settings.sql");

    @Test
    void dosyaVar_utf8BomsuzVeAnahtarlarTamdir() throws Exception {
        assertThat(SQL).exists();
        byte[] raw = Files.readAllBytes(SQL);
        assertThat(raw.length >= 3 && (raw[0] & 0xFF) == 0xEF && (raw[1] & 0xFF) == 0xBB && (raw[2] & 0xFF) == 0xBF)
                .as("BOM olmamali").isFalse();
        String sql = new String(raw, StandardCharsets.UTF_8);
        assertThat(sql).doesNotContain("�"); // gecersiz UTF-8 bayti
        for (String key : new String[] {"legal.controller.name", "legal.controller.address",
                "legal.controller.email", "support_email", "legal.hosting.location",
                "legal.controller.jurisdiction", "legal.controller.relation"}) {
            assertThat(sql).as(key).contains("('" + key + "', $v$");
        }
        assertThat(sql).contains("ON CONFLICT (setting_key) DO UPDATE");
        // Bilinmeyenler bos kalir: bu betik onlara dokunmaz
        assertThat(sql).doesNotContain("('legal.controller.kep'").doesNotContain("('legal.controller.verbis'");
        assertThat(sql).contains("Yusuf Akın").contains("Gaziantep").contains("ysufakin23@gmail.com")
                .contains("resmî bir uygulaması değildir");
    }

    @Test
    void relationDegeriVarcharSiniriniAsmaz_dolarKotlarDengeli() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        // app_setting.setting_value VARCHAR(1000)
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("\\$v\\$(.*?)\\$v\\$",
                java.util.regex.Pattern.DOTALL).matcher(sql);
        int n = 0;
        while (m.find()) {
            n++;
            assertThat(m.group(1).length()).isLessThanOrEqualTo(1000);
        }
        assertThat(n).isEqualTo(7);
    }
}
