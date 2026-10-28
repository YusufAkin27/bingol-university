package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.admin.chat.action.AdminConversationExportService;
import edu.bingol.backend.crypto.AdminDecryptService;
import edu.bingol.backend.post.PostDtos;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

/**
 * V820 (hukuki metinler 4. tur, PAKET LG) betik ciktisinin yapi kontrolu (PostgreSQL'e ozel oldugundan H2'de calistirilmaz),
 * tr/en/ar belgelerinin bolum bolum esitligi, yer tutucu butunlugu ve metindeki somut beyanlarin koddaki gercek degerlerle
 * uyumu (yanlis vaat taramasi). docs/legal bu calisma dizininden gorunmuyorsa belge testleri atlanir.
 */
class LegalMigrationV820FileTest {

    private static final Path SQL = Path.of("src/main/resources/db/migration/V820__legal_terms_v4.sql");
    private static final Path DOCS = Path.of("../docs/legal");
    private static final Path SRC = Path.of("src/main/java/edu/bingol/backend");
    private static final Path PROPS = Path.of("src/main/resources/application.properties");

    /** [dosya oneki, LegalType]: bu surumde yenilenen altı tur. EXPLICIT_CONSENT ve COOKIES degismez. */
    private static final String[][] TYPES = {
            {"terms", "TERMS"}, {"privacy", "PRIVACY"}, {"kvkk", "KVKK"},
            {"community_rules", "COMMUNITY_RULES"}, {"content_removal", "CONTENT_REMOVAL"}, {"retention", "RETENTION"}};
    private static final String[] LANGS = {"tr", "en", "ar"};

    @Test
    void altiTurYeniSurum_yenidenOnaysiz_ucDilAyniNumara_bomsuz() throws Exception {
        byte[] raw = Files.readAllBytes(SQL);
        assertThat(raw.length >= 3 && (raw[0] & 0xFF) == 0xEF && (raw[1] & 0xFF) == 0xBB && (raw[2] & 0xFF) == 0xBF)
                .as("BOM olmamali").isFalse();
        String sql = new String(raw, StandardCharsets.UTF_8);
        assertThat(sql).doesNotContain("�").doesNotContain("ALTER TABLE").doesNotContain("DOĞRULANACAK");
        Set<String> changed = Set.of("TERMS", "PRIVACY", "KVKK", "COMMUNITY_RULES", "CONTENT_REMOVAL", "RETENTION");
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
            // Karar (docs/LEGAL_NOTES.md bolum 9): kullanici aleyhine esasli degisiklik yok -> yeniden onay istenmez
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
        Assumptions.assumeTrue(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        String sql = Files.readString(SQL, StandardCharsets.UTF_8);
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
        Assumptions.assumeTrue(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        for (String[] t : TYPES) {
            List<String> tr = shape(read(t[0], "tr"));
            for (String lang : new String[] {"en", "ar"}) {
                String raw = read(t[0], lang);
                assertThat(count(raw, "(?m)^# ")).as(t[0] + "_" + lang + " h1").isEqualTo(1);
                assertThat(count(raw, "(?m)^## ")).as(t[0] + "_" + lang + " h2")
                        .isEqualTo(count(read(t[0], "tr"), "(?m)^## "));
                assertThat(shape(raw)).as(t[0] + "_" + lang + " bolum sekli").isEqualTo(tr);
            }
        }
    }

    /** Yer tutucu anahtarlari (alternatif metin haric) dilden bagimsiz ayni olmali: boylece kimlik satirlari her dilde birlikte cikar. */
    @Test
    void yerTutucuAnahtarlari_ucDilde_ayni() throws Exception {
        Assumptions.assumeTrue(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        for (String[] t : TYPES) {
            List<String> tr = placeholders(read(t[0], "tr"));
            for (String lang : new String[] {"en", "ar"}) {
                assertThat(placeholders(read(t[0], lang))).as(t[0] + "_" + lang).isEqualTo(tr);
            }
            String all = read(t[0], "tr") + read(t[0], "en") + read(t[0], "ar");
            assertThat(count(all, "\\{\\{")).as(t[0]).isEqualTo(count(all, "\\}\\}"));
        }
    }

    /** Kaldirilmis ozellikler ve yanlis alici satiri hicbir dilde kalmamali. */
    @Test
    void kaldirilmisOzelliklerVeUniversiteAlicisi_metinlerde_yok() throws Exception {
        Assumptions.assumeTrue(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        for (String[] t : TYPES) {
            String tr = read(t[0], "tr");
            String en = read(t[0], "en");
            String ar = read(t[0], "ar");
            assertThat(tr).as(t[0] + " tr").doesNotContain("hikâye").doesNotContain("yorum ve hikâye")
                    .doesNotContain("etiketlediğiniz (#)").doesNotContain("Gönderi (Keşfet) videoları")
                    .doesNotContain("gönderi videoları").doesNotContain("Bingöl Üniversitesi ilgili birimleri")
                    .doesNotContain("Üniversite yönetimi / yetkili yöneticiler").doesNotContain("DOĞRULANACAK");
            assertThat(Pattern.compile("(?i)\\bstor(y|ies)\\b").matcher(en).find()).as(t[0] + " en story").isFalse();
            assertThat(en).as(t[0] + " en").doesNotContain("post videos").doesNotContain("University units / authorised administrators");
            assertThat(ar).as(t[0] + " ar").doesNotContain("القصص").doesNotContain("القصة").doesNotContain("التعليقات")
                    .doesNotContain("فيديوهات المنشورات").doesNotContain("الوحدات المعنية في جامعة بينغول");
        }
        String kvkk = read("kvkk", "tr");
        assertThat(kvkk).contains("Üniversiteye aktarım yoktur");
        assertThat(read("privacy", "tr")).contains("Bingöl Üniversitesi'ne veya birimlerine aktarmayız");
    }

    /** Metindeki somut sayilar koddaki gercek varsayilanlarla ayni (yanlis vaat taramasi). */
    @Test
    void beyanEdilenSayilar_kodVarsayilaniyla_ayni() throws Exception {
        Assumptions.assumeTrue(Files.isDirectory(DOCS), "docs/legal bu calisma dizininden gorunmuyor");
        String props = Files.readString(PROPS, StandardCharsets.UTF_8);
        // --- koddaki gercek degerler ---
        assertThat(prop(props, "app.notification.retention-days")).isEqualTo("30");
        assertThat(prop(props, "app.notification.unread-retention-days")).isEqualTo("90");
        assertThat(prop(props, "app.dbmaint.analytics-raw-days")).isEqualTo("45");
        assertThat(prop(props, "app.dbmaint.mail-sent-days")).isEqualTo("7");
        assertThat(prop(props, "app.dbmaint.mail-dead-days")).isEqualTo("30");
        assertThat(prop(props, "app.dbmaint.activity-daily-days")).isEqualTo("400");
        assertThat(prop(props, "app.dbmaint.admin-audit-days")).isEqualTo("365");
        assertThat(prop(props, "app.dbmaint.audit-long-days")).isEqualTo("730");
        assertThat(prop(props, "app.security.ban-log-retention-days")).isEqualTo("90");
        assertThat(prop(props, "app.support.public-ticket-retention-days")).isEqualTo("365");
        assertThat(prop(props, "app.chat.media.view-once-retention-days")).isEqualTo("365");
        assertThat(prop(props, "app.chat.event-room-close-days")).isEqualTo("7");
        assertThat(prop(props, "app.chat.media.max-attachments-per-message")).isEqualTo("10");
        assertThat(prop(props, "app.chat.media.video-max-seconds")).isEqualTo("60");
        assertThat(prop(props, "app.chat.media.video-max-bytes")).isEqualTo("41943040"); // 40 MB
        assertThat(prop(props, "app.media.chat.max-dimension")).isEqualTo("1600");
        assertThat(prop(props, "app.post.media.deleted-retention-days")).isEqualTo("30");
        assertThat(prop(props, "app.post.media.unattached-hours")).isEqualTo("24");
        assertThat(props).contains("jwt.access-ttl-minutes=15").contains("jwt.refresh-ttl-days=30");
        assertThat(PostDtos.MAX_WORDS).isEqualTo(7);
        assertThat(AdminDecryptService.MIN_REASON).isEqualTo(10);
        assertThat(AdminGuardPolicy.CHAT_MIN_REASON).isEqualTo(10);
        assertThat(AdminConversationExportService.MIN_REASON).isEqualTo(20);
        String mod = src("moderation/ModerationProperties.java");
        assertThat(mod).contains("@DefaultValue(\"3\") int autoHideThreshold")
                .contains("@DefaultValue(\"3\") int strikeSuspendThreshold")
                .contains("@DefaultValue(\"180\") int strikeWindowDays");
        assertThat(src("mail/campaign/MailCampaignDispatcher.java")).contains("app.mail.campaign-retention-days:180");
        assertThat(src("profile/ContactMatchService.java")).contains("MAX_HASHES = 500");
        assertThat(src("export/DataExportController.java")).contains("limiter.check(\"export:user:\" + uid, 3, Duration.ofDays(1))");
        assertThat(src("moderation/AppealController.java")).contains("limiter.check(\"appeal:user:\" + uid, 5, Duration.ofDays(1))");
        assertThat(src("auth/token/VerificationService.java")).contains("CODE_TTL = Duration.ofMinutes(10)")
                .contains("MAX_ATTEMPTS = 5");

        // --- turkce metindeki beyanlar ---
        String terms = read("terms", "tr");
        assertThat(terms).contains("(15 dakika)").contains("en çok 30 gün geçerlidir").contains("10 dakika geçerlidir")
                .contains("mesaj başına en çok 10 ek").contains("en çok 1600 piksel")
                .contains("en çok 60 saniye ve 40 MB").contains("en çok 7 kelimelik")
                .contains("en az 10 karakter").contains("en az 20 karakter").contains("730 gün saklanır")
                .contains("365 gün** (ayarlanabilir süre)").contains("180 günlük pencerede çözülmüş 3 ihlal")
                .contains("varsayılan olarak 7 gün içinde kapanır");
        String privacy = read("privacy", "tr");
        assertThat(privacy).contains("en çok 500 adet").contains("günde 3 kez")
                .contains("Okunmuş bildirim 30 gün").contains("**45 gün**").contains("**400 gün**")
                .contains("Varsayılan **90 gün**").contains("30 gün sonra diskten silinir")
                .contains("24 saat sonra silinir").contains("Yönetici işlem kaydı (IP dahil) 365 gün")
                .contains("730 gün (kayıtlar yalnız eklenir").contains("Kampanya bitiminden 180 gün sonra silinir");
                String removal = read("content_removal", "tr");
        assertThat(removal).contains("varsayılan olarak 90 gün saklanır").doesNotContain("mevzuatın öngördüğü süre boyunca, bütünlüğü");
        assertThat(read("community_rules", "tr")).contains("180 gün içinde çözülmüş 3 ihlalde").contains("günde en fazla 5 itiraz");
        assertThat(read("kvkk", "tr")).contains("730 gün").contains("365 gün").contains("en az 10 karakter");

        // --- sayilar en/ar'da da ayni (rakamlar dilden bagimsiz) ---
        for (String lang : new String[] {"en", "ar"}) {
            String t = read("terms", lang);
            for (String n : new String[] {"1600", "730", "180", "365", "40", "60", "20", "10", "7"}) {
                assertThat(t).as("terms_" + lang + " " + n).contains(n);
            }
            String p = read("privacy", lang);
            for (String n : new String[] {"500", "400", "45", "90", "180", "365", "730", "30", "200"}) {
                assertThat(p).as("privacy_" + lang + " " + n).contains(n);
            }
            assertThat(read("community_rules", lang)).contains("180").contains("5").contains("7");
            assertThat(read("content_removal", lang)).contains("90");
        }
    }

    // ---------------------------------------------------------------- yardimcilar

    private static String read(String prefix, String lang) throws Exception {
        return Files.readString(DOCS.resolve(prefix + "_" + lang + ".md"), StandardCharsets.UTF_8)
                .replace("\r\n", "\n").replace("\r", "\n");
    }

    private static String src(String rel) throws Exception {
        return Files.readString(SRC.resolve(rel), StandardCharsets.UTF_8);
    }

    private static String prop(String props, String key) {
        Matcher m = Pattern.compile("(?m)^" + Pattern.quote(key) + "=(?:\\$\\{[A-Z_]+:)?(\\d+)\\}?\\s*$").matcher(props);
        assertThat(m.find()).as(key).isTrue();
        return m.group(1);
    }

    /** Her bolum icin "no|madde|tablo satiri|madde isareti|alinti|baglanti|yer tutucu" imzasi (baslik satiri sayilmaz). */
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

    /** Yer tutucularin yalniz anahtar kismi (| sonrasi alternatif metin atilir), sirali. */
    private static List<String> placeholders(String md) {
        TreeMap<String, Integer> counts = new TreeMap<>();
        Matcher m = Pattern.compile("\\{\\{([?/]?)([A-Za-z0-9_.]+)(?:\\|[^}]*)?\\}\\}").matcher(md);
        while (m.find()) {
            counts.merge(m.group(1) + m.group(2), 1, Integer::sum);
        }
        List<String> out = new ArrayList<>();
        counts.forEach((k, v) -> out.add(k + "=" + v));
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
