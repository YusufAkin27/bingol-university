package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * T-063 (A1-26 / A8-16): her kullanici baglantili sutunun hesap silme karari kayitlidir. Flyway migration'lari
 * (uretim semasinin gercek kaynagi) taranir; kullanici kimligi tutan her "tablo.sutun" AccountDataPurger.DELETES,
 * SCRUBS, HANDLED_ELSEWHERE ya da gerekceli RETAINED listesinde olmalidir. Yeni user-sutunlu tablo eklenip listeye
 * yazilmazsa bu test KIRMIZI olur: karar (sil / anonimlestir / yasal saklama) bilincli verilsin.
 */
class AccountDataPurgerCoverageTest {

    /** Kullanici kimligi tutan sutun adlari. */
    private static final Pattern USER_COL = Pattern.compile(
            "(^|.*_)user_id|(author|owner|sender|reporter|blocker|blocked|viewer|follower|followee|uploader|adder|actor|admin)_id|.*_by");
    private static final Pattern REFERENCES_USER = Pattern.compile("REFERENCES\\s+app_user\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern DML = Pattern.compile(
            "^(?:DELETE FROM|UPDATE)\\s+(\\w+)\\s.*?\\bWHERE\\s+(\\w+)\\s*=\\s*\\?", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);

    /** Hesap silmeyle ilgisiz: kullanici KIMLIGI degil, baska bir sey. Sutun hangi tabloda olursa olsun atlanir. */
    private static final Set<String> NOT_USER_IDENTITY = Set.of(
            "app_user.id", "app_user.created_by");

    @Test
    void everyUserLinkedColumnHasADeletionDecision() throws IOException {
        Set<String> found = userColumnsFromMigrations();
        Set<String> decided = decidedColumns();

        List<String> missing = new ArrayList<>();
        for (String c : found) {
            if (!decided.contains(c)) {
                missing.add(c);
            }
        }
        assertTrue(missing.isEmpty(),
                "Hesap silme karari olmayan kullanici sutunlari (AccountDataPurger.DELETES/SCRUBS/HANDLED_ELSEWHERE/"
                        + "RETAINED + docs/DATABASE.md matrisi): " + new TreeSet<>(missing));
    }

    /** Listeler guncel kalsin: semada olmayan (silinmis/yanlis yazilmis) giris varsa kirilir. */
    @Test
    void noStaleEntriesInDecisionLists() throws IOException {
        Set<String> found = userColumnsFromMigrations();
        List<String> stale = new ArrayList<>();
        for (String c : AccountDataPurger.HANDLED_ELSEWHERE.keySet()) {
            if (!found.contains(c)) {
                stale.add("HANDLED_ELSEWHERE:" + c);
            }
        }
        for (String c : AccountDataPurger.RETAINED.keySet()) {
            if (!found.contains(c)) {
                stale.add("RETAINED:" + c);
            }
        }
        for (String c : deleteAndScrubColumns()) {
            if (!found.contains(c)) {
                stale.add("DELETES/SCRUBS:" + c);
            }
        }
        assertTrue(stale.isEmpty(), "Semada bulunmayan giris(ler): " + stale);
    }

    /** Ayni sutun hem silinip hem 'korunan' diye yazilamaz. */
    @Test
    void noColumnIsBothDeletedAndRetained() {
        Set<String> deleted = new LinkedHashSet<>(deleteAndScrubColumns());
        List<String> both = new ArrayList<>();
        for (String c : AccountDataPurger.RETAINED.keySet()) {
            if (deleted.contains(c) || AccountDataPurger.HANDLED_ELSEWHERE.containsKey(c)) {
                both.add(c);
            }
        }
        assertTrue(both.isEmpty(), "Hem silinen hem korunan: " + both);
    }

    @Test
    void retainedEntriesCarryAReason() {
        AccountDataPurger.RETAINED.forEach((k, v) -> assertTrue(v != null && v.length() >= 8, "gerekce yok: " + k));
    }

    // --- yardimcilar ---

    private static Set<String> decidedColumns() {
        Set<String> out = new LinkedHashSet<>(deleteAndScrubColumns());
        out.addAll(AccountDataPurger.HANDLED_ELSEWHERE.keySet());
        out.addAll(AccountDataPurger.RETAINED.keySet());
        return out;
    }

    /** DELETES/SCRUBS SQL'lerinden "tablo.sutun" (WHERE kosul sutunu). */
    private static List<String> deleteAndScrubColumns() {
        List<String> out = new ArrayList<>();
        List<String> all = new ArrayList<>(AccountDataPurger.DELETES);
        all.addAll(AccountDataPurger.SCRUBS);
        for (String sql : all) {
            Matcher m = DML.matcher(sql);
            assertTrue(m.find(), "Ayristirilamayan SQL: " + sql);
            out.add(m.group(1).toLowerCase(Locale.ROOT) + "." + m.group(2).toLowerCase(Locale.ROOT));
        }
        // SCRUBS 'UPDATE poll_vote SET user_id = NULL WHERE user_id = ?' gibi: ayni sutun
        return out;
    }

    /** Migration'lari surum sirasiyla okuyup (CREATE/ALTER/DROP) kullanici kimligi tutan "tablo.sutun" kumesini cikarir. */
    static Set<String> userColumnsFromMigrations() throws IOException {
        Path dir = Path.of("src/main/resources/db/migration");
        List<Path> files;
        try (Stream<Path> s = Files.list(dir)) {
            files = s.filter(p -> p.getFileName().toString().matches("V\\d+__.*\\.sql"))
                    .sorted(Comparator.comparingInt(p -> version(p.getFileName().toString()))).toList();
        }
        Map<String, Set<String>> tables = new LinkedHashMap<>();
        Map<String, Set<String>> refs = new LinkedHashMap<>();
        for (Path f : files) {
            String sql = Files.readString(f, StandardCharsets.UTF_8).replaceAll("--[^\\n]*", "");
            parseCreates(sql, tables, refs);
            Matcher add = Pattern.compile("ALTER\\s+TABLE\\s+(?:ONLY\\s+)?(?:IF EXISTS\\s+)?(\\w+)\\s+ADD\\s+(?:COLUMN\\s+)?(?:IF NOT EXISTS\\s+)?(\\w+)([^;]*);",
                    Pattern.CASE_INSENSITIVE).matcher(sql);
            while (add.find()) {
                String col = add.group(2).toLowerCase(Locale.ROOT);
                if (col.matches("constraint|primary|foreign|unique|check")) {
                    continue;
                }
                String t = add.group(1).toLowerCase(Locale.ROOT);
                tables.computeIfAbsent(t, k -> new LinkedHashSet<>()).add(col);
                if (REFERENCES_USER.matcher(add.group(3)).find()) {
                    refs.computeIfAbsent(t, k -> new LinkedHashSet<>()).add(col);
                }
            }
            Matcher dropCol = Pattern.compile("ALTER\\s+TABLE\\s+(\\w+)\\s+DROP\\s+COLUMN\\s+(?:IF EXISTS\\s+)?(\\w+)",
                    Pattern.CASE_INSENSITIVE).matcher(sql);
            while (dropCol.find()) {
                Set<String> cols = tables.get(dropCol.group(1).toLowerCase(Locale.ROOT));
                if (cols != null) {
                    cols.remove(dropCol.group(2).toLowerCase(Locale.ROOT));
                }
            }
            Matcher rename = Pattern.compile("ALTER\\s+TABLE\\s+(\\w+)\\s+RENAME\\s+COLUMN\\s+(\\w+)\\s+TO\\s+(\\w+)",
                    Pattern.CASE_INSENSITIVE).matcher(sql);
            while (rename.find()) {
                Set<String> cols = tables.get(rename.group(1).toLowerCase(Locale.ROOT));
                if (cols != null && cols.remove(rename.group(2).toLowerCase(Locale.ROOT))) {
                    cols.add(rename.group(3).toLowerCase(Locale.ROOT));
                }
            }
            Matcher drop = Pattern.compile("DROP\\s+TABLE\\s+(?:IF EXISTS\\s+)?([\\w,\\s]+?)(?:\\s+CASCADE)?\\s*;",
                    Pattern.CASE_INSENSITIVE).matcher(sql);
            while (drop.find()) {
                for (String t : drop.group(1).split(",")) {
                    tables.remove(t.trim().toLowerCase(Locale.ROOT));
                    refs.remove(t.trim().toLowerCase(Locale.ROOT));
                }
            }
        }
        Set<String> out = new LinkedHashSet<>();
        tables.forEach((t, cols) -> {
            for (String c : cols) {
                String key = t + "." + c;
                if (NOT_USER_IDENTITY.contains(key)) {
                    continue;
                }
                boolean fk = refs.getOrDefault(t, Set.of()).contains(c);
                if (USER_COL.matcher(c).matches() || fk) {
                    // app_user kendisi (anonimlestirilir) ve kullanici-disi *_by yardimcilari atlanir
                    if (!t.equals("app_user")) {
                        out.add(key);
                    }
                }
            }
        });
        return out;
    }

    private static void parseCreates(String sql, Map<String, Set<String>> tables, Map<String, Set<String>> refs) {
        Matcher m = Pattern.compile("CREATE\\s+TABLE\\s+(?:IF NOT EXISTS\\s+)?(\\w+)\\s*\\(", Pattern.CASE_INSENSITIVE).matcher(sql);
        while (m.find()) {
            String table = m.group(1).toLowerCase(Locale.ROOT);
            int depth = 1;
            int i = m.end();
            int start = i;
            List<String> parts = new ArrayList<>();
            while (i < sql.length() && depth > 0) {
                char c = sql.charAt(i);
                if (c == '(') {
                    depth++;
                } else if (c == ')') {
                    depth--;
                    if (depth == 0) {
                        parts.add(sql.substring(start, i));
                    }
                } else if (c == ',' && depth == 1) {
                    parts.add(sql.substring(start, i));
                    start = i + 1;
                }
                i++;
            }
            Set<String> cols = new LinkedHashSet<>();
            Set<String> fkCols = new LinkedHashSet<>();
            for (String part : parts) {
                String p = part.trim();
                if (p.isEmpty()) {
                    continue;
                }
                String first = p.split("\\s+")[0].toLowerCase(Locale.ROOT);
                if (first.matches("primary|constraint|unique|foreign|check|like|exclude")) {
                    Matcher fk = Pattern.compile("FOREIGN\\s+KEY\\s*\\((\\w+)\\)\\s*REFERENCES\\s+app_user",
                            Pattern.CASE_INSENSITIVE).matcher(p);
                    if (fk.find()) {
                        fkCols.add(fk.group(1).toLowerCase(Locale.ROOT));
                    }
                    continue;
                }
                cols.add(first);
                if (REFERENCES_USER.matcher(p).find()) {
                    fkCols.add(first);
                }
            }
            tables.put(table, cols);
            refs.put(table, fkCols);
        }
    }

    private static int version(String name) {
        Matcher m = Pattern.compile("V(\\d+)__").matcher(name);
        return m.find() ? Integer.parseInt(m.group(1)) : 0;
    }
}
