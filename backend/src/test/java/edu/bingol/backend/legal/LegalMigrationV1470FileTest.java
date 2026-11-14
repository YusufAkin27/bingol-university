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
 * V1470 (hukuki metinler 5. tur: e-posta alan adi kisiti kalkti, Google/Apple girisi) ve V1471 (SSS) dosya kontrolu.
 * SQL PostgreSQL'e ozel oldugundan H2'de calistirilmaz; burada yapi, kaynak (docs/legal) esitligi, tr/en/ar bolum esitligi
 * ve "yalniz bingol.edu.tr" ifadelerinin kalmadigi denetlenir. docs/legal gorunmuyorsa belge testleri atlanir.
 */
class LegalMigrationV1470FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V1470__legal_texts_any_email.sql");
    private static final Path FAQ_SQL = Path.of("src/main/resources/db/migration/V1471__faq_any_email.sql");
    private static final Path V3 = Path.of("src/main/resources/db/migration/V3__support.sql");
    private static final Path DOCS = Path.of("../docs/legal");
    private static final String[][] TYPES = {{"terms", "TERMS"}, {"privacy", "PRIVACY"}, {"kvkk", "KVKK"}};
    private static final String[] LANGS = {"tr", "en", "ar"};

    @Test
    void ucTurYeniSurum_yenidenOnaysiz_ucDilAyniNumara_bomsuz() throws Exception {
        byte[] raw = Files.readAllBytes(SQL);
        assertThat(raw.length >= 3 && (raw[0] & 0xFF) == 0xEF && (raw[1] & 0xFF) == 0xBB && (raw[2] & 0xFF) == 0xBF)
                .as("BOM olmamali").isFalse();
        String sql = new String(raw, StandardCharsets.UTF_8);
        assertThat(sql).doesNotContain("�").doesNotContain("ALTER TABLE").doesNotContain("DOĞRULANACAK");
        Set<String> changed = Set.of("TERMS", "PRIVACY", "KVKK");
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
            // Karar (docs/LEGAL_NOTES.md bolum 14): kisit kaldirildi, yeni riza gerektiren islem yok -> yeniden onay istenmez
            assertThat(m.group(1)).as(t.name()).isEqualTo("FALSE");
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

    /** "Yalniz bingol.edu.tr / yalniz universite e-postasi ile kayit" ifadeleri hicbir dilde kalmamali; yeni gerceklik yazili olmali. */
    @Test
    void alanAdiKisiti_metinlerde_yok_yeniGerceklik_var() throws Exception {
        LegalDocsGuard.requireDocs(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        for (String[] t : TYPES) {
            String tr = read(t[0], "tr");
            String en = read(t[0], "en");
            String ar = read(t[0], "ar");
            assertThat(tr).as(t[0] + " tr").doesNotContain("yalnızca `bingol.edu.tr`").doesNotContain("Yalnızca bingol.edu.tr")
                    .doesNotContain("kurumsal e-posta").doesNotContain("alan adını (bingol.edu.tr)")
                    .doesNotContain("üniversite öğrenci/personel e-postasıyla").doesNotContain("içindir ve yalnızca");
            assertThat(en).as(t[0] + " en").doesNotContain("is only possible with an e-mail address ending")
                    .doesNotContain("only with a bingol.edu.tr e-mail").doesNotContain("institutional e-mail")
                    .doesNotContain("Institutional e-mail").doesNotContain("domain name of the e-mail address")
                    .doesNotContain("university student/staff e-mail");
            assertThat(ar).as(t[0] + " ar").doesNotContain("الإلكتروني المؤسسي").doesNotContain("اسم نطاق البريد الإلكتروني")
                    .doesNotContain("ببريد bingol.edu.tr فقط").doesNotContain("لطالب/موظف في الجامعة");
        }
        String terms = read("terms", "tr");
        assertThat(terms).contains("herhangi bir e-posta adresiyle").contains("`bingol.edu.tr` uzantılı e-posta adresi zorunlu değildir")
                .contains("6 haneli doğrulama kodunu").contains("10 dakika geçerlidir");
        assertThat(read("terms", "en")).contains("is not required to register").contains("6-digit verification code");
        assertThat(read("terms", "ar")).contains("لا يُشترط للتسجيل").contains("6 أرقام");
        // Google / Apple ile giris: Gizlilik ve KVKK'da veri kategorisi (her dilde)
        for (String lang : LANGS) {
            assertThat(read("privacy", lang)).as("privacy " + lang).contains("Google").contains("Apple");
            assertThat(read("kvkk", lang)).as("kvkk " + lang).contains("Google").contains("Apple");
        }
    }

    /** SSS: yalniz V3 tohumundaki eski metinle birebir ayni satirlar guncellenir; eski metinler V3'te gercekten var. */
    @Test
    void sss_yalnizEskiVarsayilanBirebirEsleserekGuncellenir() throws Exception {
        String faq = Files.readString(FAQ_SQL, StandardCharsets.UTF_8);
        String v3 = Files.readString(V3, StandardCharsets.UTF_8);
        assertThat(faq.getBytes(StandardCharsets.UTF_8)[0] & 0xFF).as("BOM olmamali").isNotEqualTo(0xEF);
        assertThat(count(faq, "(?m)^UPDATE faq_item")).isEqualTo(3);
        Matcher m = Pattern.compile("AND question = '([^']*)'\\s+AND answer = '([^']*)'").matcher(faq);
        int n = 0;
        while (m.find()) {
            n++;
            assertThat(v3).as(m.group(1)).contains("'" + m.group(1) + "', '" + m.group(2) + "'");
        }
        assertThat(n).isEqualTo(3);
        assertThat(faq).doesNotContain("DELETE").doesNotContain("INSERT");
    }

    // ---------------------------------------------------------------- yardimcilar

    private static String read(String prefix, String lang) throws Exception {
        // V1910'da metinler degisti: V1470 kaynaklari docs/legal/archive/v1470 altinda dondurulmustur
        Path archived = DOCS.resolve("archive/v1470").resolve(prefix + "_" + lang + ".md");
        Path file = Files.exists(archived) ? archived : DOCS.resolve(prefix + "_" + lang + ".md");
        return Files.readString(file, StandardCharsets.UTF_8)
                .replace("\r\n", "\n").replace("\r", "\n");
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
