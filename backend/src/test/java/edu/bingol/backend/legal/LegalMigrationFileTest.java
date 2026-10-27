package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/** V290 betik ciktisinin yapi kontrolu (PostgreSQL'e ozel oldugundan H2'de calistirilmaz). */
class LegalMigrationFileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V290__legal_texts_v3.sql");

    @Test
    void sekizTurIkiDil_surumHesabiMaxArtiBir() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        assertThat(sql).doesNotStartWith("﻿");
        assertThat(LegalType.values()).hasSize(8);
        for (LegalType t : LegalType.values()) {
            assertThat(sql).contains("'" + t.name() + "', 'tr', v,").contains("'" + t.name() + "', 'en', v,");
            assertThat(sql).contains("SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = '"
                    + t.name() + "'");
            assertThat(sql).contains("UPDATE legal_document SET active = FALSE WHERE type = '" + t.name() + "' AND active;");
        }
        assertThat(count(sql, "INSERT INTO legal_document")).isEqualTo(8);
        Matcher m = Pattern.compile("legal_type_check CHECK \\(type IN \\(([^)]*)\\)\\)").matcher(sql);
        assertThat(m.find()).isTrue();
        for (LegalType t : LegalType.values()) {
            assertThat(m.group(1)).contains("'" + t.name() + "'");
        }
    }

    @Test
    void dolarEtiketleriDengeliVeTekrarsiz() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        Matcher m = Pattern.compile("\\$([a-z]+_[a-z_]+)\\$").matcher(sql);
        Map<String, Integer> tags = new HashMap<>();
        while (m.find()) {
            tags.merge(m.group(1), 1, Integer::sum);
        }
        assertThat(tags).isNotEmpty();
        tags.forEach((tag, n) -> assertThat(n).as(tag).isEqualTo(2));
    }

    @Test
    void zorunluOnayTurleriTamDortu() {
        long required = Arrays.stream(LegalType.values()).filter(LegalType::isSignupRequired).count();
        assertThat(required).isEqualTo(4);
        assertThat(LegalType.parse("explicit-consent")).isEqualTo(LegalType.EXPLICIT_CONSENT);
        assertThat(LegalType.parse("content_removal")).isEqualTo(LegalType.CONTENT_REMOVAL);
    }

    @Test
    void yerTutucularYalnizBilinenAnahtarlar() throws Exception {
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
        Matcher m = Pattern.compile("\\{\\{[?/]?([A-Za-z0-9_.]+)").matcher(sql);
        Set<String> allowed = Set.of("controller.name", "controller.address", "controller.email", "controller.kep",
                "controller.verbis", "support.email", "hosting.location");
        while (m.find()) {
            assertThat(allowed).as(m.group(0)).contains(m.group(1));
        }
    }

    private static int count(String s, String sub) {
        int n = 0;
        for (int i = s.indexOf(sub); i >= 0; i = s.indexOf(sub, i + 1)) {
            n++;
        }
        return n;
    }
}
