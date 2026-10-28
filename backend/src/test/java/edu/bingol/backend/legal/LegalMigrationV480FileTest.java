package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/** V480 betik ciktisinin yapi kontrolu (PostgreSQL'e ozel oldugundan H2'de calistirilmaz). */
class LegalMigrationV480FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V480__legal_texts_v3.sql");
    private static final Set<LegalType> NEW_VERSION = Set.of(LegalType.TERMS, LegalType.PRIVACY,
            LegalType.CONTENT_REMOVAL);

    @Test
    void degisenTurlerUcDilYeniSurum_digerlerineYalnizArapcaEklenir() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        assertThat(sql).doesNotStartWith("\uFEFF").doesNotContain("ALTER TABLE").doesNotContain("DOĞRULANACAK");
        for (LegalType t : LegalType.values()) {
            if (NEW_VERSION.contains(t)) {
                assertThat(sql).contains("'" + t.name() + "', 'tr', v,").contains("'" + t.name() + "', 'en', v,")
                        .contains("'" + t.name() + "', 'ar', v,");
                assertThat(sql).contains("SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = '"
                        + t.name() + "'");
                assertThat(sql).contains("UPDATE legal_document SET active = FALSE WHERE type = '" + t.name()
                        + "' AND active;");
                Matcher m = Pattern.compile("'" + t.name() + "', 'ar', v, .*?\\$c_[a-z_]+_ar\\$, (TRUE|FALSE), TRUE\\)",
                        Pattern.DOTALL).matcher(sql);
                assertThat(m.find()).as(t.name()).isTrue();
                // Yeniden onay yalniz kayitta zorunlu turlerde
                assertThat(m.group(1)).as(t.name()).isEqualTo(t.isSignupRequired() ? "TRUE" : "FALSE");
            } else {
                // Yeni surum yok: mevcut tr surumunun yeniden onayi tetiklenmez
                assertThat(sql).doesNotContain("WHERE type = '" + t.name() + "';");
                assertThat(sql).contains("SELECT '" + t.name() + "', 'ar', d.version,");
            }
        }
        // 3 yeni surum blogu + 5 yalniz-Arapca eki
        assertThat(sql.split("DO \\$do_", -1).length - 1).isEqualTo(NEW_VERSION.size());
        assertThat(sql.split("SELECT '[A-Z_]+', 'ar', d\\.version", -1).length - 1)
                .isEqualTo(LegalType.values().length - NEW_VERSION.size());
    }

    @Test
    void yerTutucularBilinenAnahtarlar_surumTurHizalamaDogru() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        Matcher m = Pattern.compile("\\{\\{[?/]?([A-Za-z0-9_.]+)").matcher(sql);
        Set<String> allowed = Set.of("controller.name", "controller.address", "controller.email", "controller.kep",
                "controller.verbis", "controller.relation", "controller.jurisdiction", "support.email",
                "hosting.location");
        while (m.find()) {
            assertThat(allowed).as(m.group(0)).contains(m.group(1));
        }
        // Yer tutucu yedek metinlerinde kapanis sorunu olmasin: acilis/kapanis sayisi esit
        assertThat(count(sql, "\\{\\{")).isEqualTo(count(sql, "\\}\\}"));
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
