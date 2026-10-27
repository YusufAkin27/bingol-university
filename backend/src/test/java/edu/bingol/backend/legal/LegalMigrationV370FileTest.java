package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/** V370 betik ciktisinin yapi kontrolu (PostgreSQL'e ozel oldugundan H2'de calistirilmaz). */
class LegalMigrationV370FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V370__legal_texts_v4.sql");
    /** COOKIES V370'te degismedi; digerleri yeni surum alir. */
    private static final Set<LegalType> CHANGED = Set.of(LegalType.TERMS, LegalType.PRIVACY, LegalType.KVKK,
            LegalType.COMMUNITY_RULES, LegalType.EXPLICIT_CONSENT, LegalType.CONTENT_REMOVAL, LegalType.RETENTION);

    @Test
    void degisenTurlerIkiDil_surumMaxArtiBir_yeniOnayYalnizZorunluTurlerde() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        assertThat(sql).doesNotStartWith("\uFEFF").doesNotContain("ALTER TABLE");
        for (LegalType t : LegalType.values()) {
            if (!CHANGED.contains(t)) {
                assertThat(sql).doesNotContain("type = '" + t.name() + "'");
                continue;
            }
            assertThat(sql).contains("'" + t.name() + "', 'tr', v,").contains("'" + t.name() + "', 'en', v,");
            assertThat(sql).contains("SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = '"
                    + t.name() + "'");
            assertThat(sql).contains("UPDATE legal_document SET active = FALSE WHERE type = '" + t.name() + "' AND active;");
            Matcher m = Pattern.compile("'" + t.name() + "', 'en', v, .*?\\$c_[a-z_]+_en\\$, (TRUE|FALSE), TRUE\\)",
                    Pattern.DOTALL).matcher(sql);
            assertThat(m.find()).as(t.name()).isTrue();
            assertThat(m.group(1)).as(t.name()).isEqualTo(t.isSignupRequired() ? "TRUE" : "FALSE");
        }
        assertThat(sql.split("INSERT INTO legal_document", -1).length - 1).isEqualTo(CHANGED.size());
    }

    @Test
    void konumIcinEskiIddiaYok_yerTutucularBilinenAnahtarlar() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        assertThat(sql).doesNotContain("Yaklaşık konum izni").doesNotContain("sunucu yeniden kodlamaz. Görsellerin");
        Matcher m = Pattern.compile("\\{\\{[?/]?([A-Za-z0-9_.]+)").matcher(sql);
        Set<String> allowed = Set.of("controller.name", "controller.address", "controller.email", "controller.kep",
                "controller.verbis", "support.email", "hosting.location");
        while (m.find()) {
            assertThat(allowed).as(m.group(0)).contains(m.group(1));
        }
    }
}
