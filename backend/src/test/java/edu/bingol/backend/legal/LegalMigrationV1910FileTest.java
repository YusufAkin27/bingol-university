package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/**
 * V1910 (hukuki metinler 6. tur: akademisyen alani, ders kaydi, QR ile ders yoklamasi, ogrenci rehberi, ders duyurulari)
 * dosya kontrolu. SQL PostgreSQL'e ozel oldugundan H2'de calistirilmaz; burada yapi, kaynak (docs/legal) esitligi, tr/en/ar
 * bolum esitligi ve metnin kodla uyumlu temel beyanlari denetlenir. docs/legal gorunmuyorsa belge testleri atlanir
 * (CI'da basarisiz olur: bkz. LegalDocsGuard).
 */
class LegalMigrationV1910FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V1910__legal_texts_academician.sql");
    private static final Path DOCS = Path.of("../docs/legal");
    private static final String[][] TYPES = {{"terms", "TERMS"}, {"privacy", "PRIVACY"}, {"kvkk", "KVKK"},
            {"retention", "RETENTION"}};
    private static final String[] LANGS = {"tr", "en", "ar"};

    @Test
    void dortTurYeniSurum_ucDilAyniNumara_bomsuz_yenidenOnayKarari() throws Exception {
        byte[] raw = Files.readAllBytes(SQL);
        assertThat(raw.length >= 3 && (raw[0] & 0xFF) == 0xEF && (raw[1] & 0xFF) == 0xBB && (raw[2] & 0xFF) == 0xBF)
                .as("BOM olmamali").isFalse();
        String sql = new String(raw, StandardCharsets.UTF_8);
        assertThat(sql).doesNotContain("�").doesNotContain("ALTER TABLE").doesNotContain("DOĞRULANACAK");
        Set<String> changed = Set.of("TERMS", "PRIVACY", "KVKK", "RETENTION");
        for (LegalType t : LegalType.values()) {
            if (!changed.contains(t.name())) {
                assertThat(sql).as(t.name()).doesNotContain("type = '" + t.name() + "'");
                continue;
            }
            assertThat(sql).contains("'" + t.name() + "', 'tr', v,").contains("'" + t.name() + "', 'en', v,")
                    .contains("'" + t.name() + "', 'ar', v,");
            assertThat(sql).contains("SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = '"
                    + t.name() + "'");
            assertThat(sql).contains("UPDATE legal_document SET active = FALSE WHERE type = '" + t.name() + "' AND active;");
            Matcher m = Pattern.compile("'" + t.name() + "', 'ar', v, .*?\\$c_[a-z_]+_ar\\$, (TRUE|FALSE), TRUE\\)",
                    Pattern.DOTALL).matcher(sql);
            assertThat(m.find()).as(t.name()).isTrue();
            // Karar (docs/LEGAL_NOTES.md bolum 15): yeni islem amaci ve veri kategorisi var -> imzada zorunlu turlerde yeniden onay;
            // saklama ozeti yalniz bilgilendirmedir.
            assertThat(m.group(1)).as(t.name()).isEqualTo(t.isSignupRequired() ? "TRUE" : "FALSE");
        }
        assertThat(sql.split("DO \\$do_", -1).length - 1).isEqualTo(changed.size());
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

    /** SQL, docs/legal kaynaklariyla birebir ayni (betik calistirildi; elle duzenleme yok). */
    @Test
    void sqlIcerigi_markdownKaynaklariylaBirebirAyni() throws Exception {
        LegalDocsGuard.requireDocs(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        String sql = Files.readString(SQL, StandardCharsets.UTF_8).replace("\r\n", "\n");
        for (String[] t : TYPES) {
            for (String lang : LANGS) {
                String raw = read(t[0], lang);
                Matcher h = Pattern.compile("^# (.+)\\n").matcher(raw);
                assertThat(h.find()).as(t[0] + "_" + lang).isTrue();
                String title = h.group(1).trim();
                String content = raw.substring(h.end()).trim();
                String tag = t[0] + "_" + lang;
                assertThat(sql).as(tag + " baslik").contains("$t_" + tag + "$" + title + "$t_" + tag + "$");
                assertThat(sql).as(tag + " icerik").contains("$c_" + tag + "$" + content + "$c_" + tag + "$");
            }
        }
    }

    /** tr ile en/ar BIRE BIR: ayni bolum sayisi/numarasi ve her bolumde ayni madde, tablo satiri, alinti, baglanti ve yer tutucu sayisi. */
    @Test
    void tr_en_ar_bolum_bolum_esit() throws Exception {
        LegalDocsGuard.requireDocs(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        for (String[] t : TYPES) {
            List<String> tr = shape(read(t[0], "tr"));
            for (String lang : new String[] {"en", "ar"}) {
                assertThat(shape(read(t[0], lang))).as(t[0] + "_" + lang + " bolum sekli").isEqualTo(tr);
            }
        }
    }

    /** Akademisyen alani beyanlari: rehber alanlari, konum/cihaz kimligi YOK, otomatik saklama suresi YOK (durust ifade), her dilde. */
    @Test
    void akademisyenBeyanlari_koduYansitir_hicbirDilde_konumVeyaUydurmaSureYok() throws Exception {
        LegalDocsGuard.requireDocs(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        for (String lang : LANGS) {
            String privacy = read("privacy", lang);
            String kvkk = read("kvkk", lang);
            String retention = read("retention", lang);
            String terms = read("terms", lang);
            // yeni bolumler var
            assertThat(privacy).as("privacy " + lang).contains("## 15. ").contains("## 16. ");
            assertThat(kvkk).as("kvkk " + lang).contains("## 12. ");
            // rehber: e-posta/fotograf gorunmez ve rehberden cikma ayari yok (acik cumle)
            assertThat(section(privacy, 15)).as("privacy15 " + lang).contains("bingol.edu.tr").contains("24");
            assertThat(section(kvkk, 12)).as("kvkk12 " + lang).contains("5/2-(f)").contains("5/2-(c)");
            // hic yeni "gun" suresi uydurulmadi: akademisyen kayitlari icin saklama satirlarinda yalniz 24 saat gecer
            assertThat(retention).as("retention " + lang).contains("24");
            // yeni surum uc dilde de konum islenmedigini korur
            assertThat(section(privacy, 15)).as("privacy15 " + lang).contains("GPS");
            assertThat(section(kvkk, 12)).as("kvkk12 " + lang).contains("GPS");
            // KVKK 12: veri sorumlusu / VERBIS gibi alanlar degismedi (yer tutucu satirlari)
            assertThat(kvkk).contains("{{controller.name}}").contains("{{?controller.verbis}}");
            // Kullanim Kosullari: universiteyle iliski cumlesi (15.1 yer tutucusu) AYNEN korunur
            assertThat(terms).contains("{{controller.relation|");
        }
        assertThat(section(read("privacy", "tr"), 15)).contains("Onay, üniversitenin kişiyi personel olarak doğruladığı anlamına gelmez")
                .contains("adınız, öğrenci numaranız, fakülteniz, bölümünüz ve sınıfınız").contains("görünmez");
        assertThat(section(read("privacy", "tr"), 15)).doesNotContain("konum izni isteriz");
    }

    // ---------------------------------------------------------------- yardimcilar

    private static String read(String prefix, String lang) throws Exception {
        return Files.readString(DOCS.resolve(prefix + "_" + lang + ".md"), StandardCharsets.UTF_8)
                .replace("\r\n", "\n").replace("\r", "\n");
    }

    private static String section(String md, int n) {
        Matcher m = Pattern.compile("(?m)^## " + n + "\\. .*$").matcher(md);
        assertThat(m.find()).as("bolum " + n).isTrue();
        int start = m.end();
        Matcher next = Pattern.compile("(?m)^## \\d+\\. ").matcher(md);
        int end = md.length();
        if (next.find(start)) {
            end = next.start();
        }
        return md.substring(start, end);
    }

    /** Her bolum icin "no|madde|tablo satiri|madde isareti|alinti|baglanti|yer tutucu" imzasi. */
    private static List<String> shape(String md) {
        List<String> out = new ArrayList<>();
        String[] parts = md.split("(?m)^## ", -1);
        for (int i = 0; i < parts.length; i++) {
            String sec = parts[i];
            String number = "";
            if (i > 0) {
                Matcher h = Pattern.compile("^(\\d+)\\.").matcher(sec);
                number = h.find() ? h.group(1) : "?";
                int nl = sec.indexOf('\n');
                sec = nl < 0 ? "" : sec.substring(nl + 1);
            }
            out.add(number + "|num=" + count(sec, "(?m)^\\d+\\. ") + "|row=" + count(sec, "(?m)^\\|")
                    + "|bullet=" + count(sec, "(?m)^- ") + "|quote=" + count(sec, "(?m)^> ")
                    + "|link=" + count(sec, "\\]\\(/") + "|ph=" + count(sec, "\\{\\{"));
        }
        return out;
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
