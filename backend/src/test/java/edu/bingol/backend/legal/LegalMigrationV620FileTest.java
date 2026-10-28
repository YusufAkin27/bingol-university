package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/**
 * V620 (saklama suresi duzeltmesi) betik ciktisinin yapi kontrolu (PostgreSQL'e ozel oldugundan H2'de calistirilmaz) ve
 * yayinlanan gun sayilarinin koddaki gercek varsayilanlarla ayni olmasi (denetim L13).
 */
class LegalMigrationV620FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V620__legal_retention_fix.sql");
    private static final Path PROPS = Path.of("src/main/resources/application.properties");
    private static final Set<LegalType> TYPES = Set.of(LegalType.RETENTION, LegalType.PRIVACY, LegalType.KVKK);

    @Test
    void yalnizUcTurYeniSurum_yenidenOnaysiz_ucDilAyniNumara() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        assertThat(sql).doesNotStartWith("﻿").doesNotContain("ALTER TABLE").doesNotContain("DOĞRULANACAK");
        for (LegalType t : LegalType.values()) {
            if (TYPES.contains(t)) {
                assertThat(sql).contains("'" + t.name() + "', 'tr', v,").contains("'" + t.name() + "', 'en', v,")
                        .contains("'" + t.name() + "', 'ar', v,");
                assertThat(sql).contains("SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = '"
                        + t.name() + "'");
                assertThat(sql).contains("UPDATE legal_document SET active = FALSE WHERE type = '" + t.name()
                        + "' AND active;");
                Matcher m = Pattern.compile("'" + t.name() + "', 'ar', v, .*?\\$c_[a-z_]+_ar\\$, (TRUE|FALSE), TRUE\\)",
                        Pattern.DOTALL).matcher(sql);
                assertThat(m.find()).as(t.name()).isTrue();
                // Bilgilendirme duzeltmesi: yeniden onay istenmez (gerekce docs/LEGAL_NOTES.md)
                assertThat(m.group(1)).as(t.name()).isEqualTo("FALSE");
            } else {
                assertThat(sql).doesNotContain("type = '" + t.name() + "'");
            }
        }
        assertThat(sql.split("DO \\$do_", -1).length - 1).isEqualTo(TYPES.size());
    }

    @Test
    void yerTutucularBilinenAnahtarlarVeDengeli() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        Matcher m = Pattern.compile("\\{\\{[?/]?([A-Za-z0-9_.]+)").matcher(sql);
        Set<String> allowed = Set.of("controller.name", "controller.address", "controller.email", "controller.kep",
                "controller.verbis", "controller.relation", "controller.jurisdiction", "support.email",
                "hosting.location");
        while (m.find()) {
            assertThat(allowed).as(m.group(0)).contains(m.group(1));
        }
        assertThat(count(sql, "\\{\\{")).isEqualTo(count(sql, "\\}\\}"));
    }

    /** Metindeki gun sayilari application.properties varsayilanlariyla ayni (saklama beyani koddan sapmasin). */
    @Test
    void beyanEdilenSureler_kodVarsayilaniyla_ayni() throws Exception {
        Path doc = Path.of("../docs/legal/retention_tr.md");
        org.junit.jupiter.api.Assumptions.assumeTrue(Files.exists(doc), "docs/legal bu calisma dizininden gorunmuyor");
        String props = Files.readString(PROPS, StandardCharsets.UTF_8);
        String retentionTr = Files.readString(doc, StandardCharsets.UTF_8);
        assertThat(default_(props, "app.notification.retention-days")).isEqualTo("30");
        assertThat(default_(props, "app.notification.unread-retention-days")).isEqualTo("90");
        assertThat(default_(props, "app.dbmaint.analytics-raw-days")).isEqualTo("45");
        assertThat(default_(props, "app.dbmaint.mail-sent-days")).isEqualTo("7");
        assertThat(default_(props, "app.dbmaint.mail-dead-days")).isEqualTo("30");
        assertThat(default_(props, "app.dbmaint.activity-daily-days")).isEqualTo("400");
        assertThat(default_(props, "app.dbmaint.admin-audit-days")).isEqualTo("365");
        assertThat(default_(props, "app.dbmaint.audit-long-days")).isEqualTo("730");
        assertThat(default_(props, "app.security.ban-log-retention-days")).isEqualTo("90");
        assertThat(default_(props, "app.support.public-ticket-retention-days")).isEqualTo("365");
        assertThat(retentionTr)
                .contains("Okunmuş 30 gün, okunmamış 90 gün")
                .contains("| 45 gün (hesap silinince hemen) |")
                .contains("Gönderilenler 7 gün, gönderilemeyenler (başarısız) 30 gün")
                .contains("400 gün (hesap silinince hemen)")
                .contains("| Yönetici işlem kaydı (IP dahil) | 365 gün |")
                .contains("730 gün (kayıtlar yalnız eklenir")
                .doesNotContain("180 gün | Silinir |");
    }

    private static String default_(String props, String key) {
        Matcher m = Pattern.compile("(?m)^" + Pattern.quote(key) + "=\\$\\{[A-Z_]+:(\\d+)\\}").matcher(props);
        assertThat(m.find()).as(key).isTrue();
        return m.group(1);
    }

    private static int count(String s, String regex) {
        Matcher m = Pattern.compile(regex).matcher(s);
        int n = 0;
        while (m.find()) {
            n++;
        }
        return n;
    }
}
