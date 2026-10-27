package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;

class LegalTemplateTest {

    @Test
    void doldurur_bosuSilerYedegiKullanir() {
        Map<String, String> v = Map.of("controller.name", "Bingöl Üniversitesi", "controller.kep", " ");
        assertThat(LegalTemplate.render("A: {{controller.name}}", v)).isEqualTo("A: Bingöl Üniversitesi");
        assertThat(LegalTemplate.render("B: {{controller.kep}}x", v)).isEqualTo("B: x");
        assertThat(LegalTemplate.render("C: {{support.email|Destek bölümü}}", v)).isEqualTo("C: Destek bölümü");
        assertThat(LegalTemplate.render("D: {{yok.anahtar}}.", v)).isEqualTo("D: .");
    }

    @Test
    void satirBlogu_bossaTumSatirDuser_tabloBozulmaz() {
        String t = "| a | b |\n|---|---|\n{{?controller.kep}}| KEP | {{controller.kep}} |{{/controller.kep}}\n| z | y |";
        assertThat(LegalTemplate.render(t, Map.of())).isEqualTo("| a | b |\n|---|---|\n| z | y |");
        assertThat(LegalTemplate.render(t, Map.of("controller.kep", "x@hs01.kep.tr")))
                .isEqualTo("| a | b |\n|---|---|\n| KEP | x@hs01.kep.tr |\n| z | y |");
    }

    @Test
    void satirIciBlok_kosulluCumleParcasi() {
        String t = "Adres{{?controller.address}}: {{controller.address}}{{/controller.address}}.";
        assertThat(LegalTemplate.render(t, Map.of())).isEqualTo("Adres.");
        assertThat(LegalTemplate.render(t, Map.of("controller.address", "Bingöl"))).isEqualTo("Adres: Bingöl.");
    }

    @Test
    void hamYerTutucuAsla_gorunmez() {
        String out = LegalTemplate.render("x {{?a}}1{{/a}} {{b}} {{c|d}} {{?e}}{{e}}{{/e}}", Map.of());
        assertThat(out).doesNotContain("{{").doesNotContain("}}");
    }

    @Test
    void ozelKarakterliDegerGuvenliYazilir() {
        assertThat(LegalTemplate.render("{{k}}", Map.of("k", "a$1\\b"))).isEqualTo("a$1\\b");
    }
}
