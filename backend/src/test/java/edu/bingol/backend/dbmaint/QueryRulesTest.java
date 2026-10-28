package edu.bingol.backend.dbmaint;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * Sorgu kurallari koruma testi (docs/DATABASE.md "Sorgu kurallari"):
 * 1) Depo arayuzlerinde parametresiz {@code List<..> findAll()} tanimlanmaz.
 * 2) {@code .findAll()} yalniz kucuk, sabit boyutlu yapilandirma tablolarinda (izin listesi) cagrilir.
 * Yeni bir yer buraya eklenecekse buyuk tablo olmadigi gerekcelendirilmelidir.
 */
class QueryRulesTest {

    private static final Path SRC = Path.of("src/main/java");
    /** Kucuk, sinirli tablolar: app_setting, access_ban_anonymizer, sync_status, kulup kategorileri. */
    private static final Set<String> FINDALL_ALLOWED = Set.of(
            "AccessBanCache.java", "AccessBanService.java", "AppInfoService.java", "LegalService.java", "StatusService.java",
            "CommunityCategoryService.java"); // kulup kategorileri: yoneticinin tanimladigi birkac satir
    private static final Pattern FIND_ALL_CALL = Pattern.compile("\\.findAll\\(\\)");
    private static final Pattern FIND_ALL_DECL = Pattern.compile("List<[^>]+>\\s+findAll\\(\\)");

    private static List<Path> javaFiles() throws IOException {
        try (Stream<Path> s = Files.walk(SRC)) {
            return s.filter(p -> p.toString().endsWith(".java")).toList();
        }
    }

    @Test
    void noParameterlessFindAllDeclarationsInRepositories() throws IOException {
        List<String> bad = new ArrayList<>();
        for (Path p : javaFiles()) {
            if (FIND_ALL_DECL.matcher(Files.readString(p)).find()) {
                bad.add(p.toString());
            }
        }
        assertTrue(bad.isEmpty(), "Sinirsiz findAll() bildirimi: " + bad);
    }

    @Test
    void findAllCallsOnlyOnSmallConfigTables() throws IOException {
        List<String> bad = new ArrayList<>();
        for (Path p : javaFiles()) {
            String name = p.getFileName().toString();
            if (!FINDALL_ALLOWED.contains(name) && FIND_ALL_CALL.matcher(Files.readString(p)).find()) {
                bad.add(p.toString());
            }
        }
        assertTrue(bad.isEmpty(), "Izin listesi disinda findAll() cagrisi (sayfalama/limit kullanin): " + bad);
    }

    @Test
    void jobsUseChunkedDeletesWithLimitParameter() throws IOException {
        String s = Files.readString(SRC.resolve("edu/bingol/backend/dbmaint/DbMaintenanceJob.java"));
        long deletes = Pattern.compile("\"DELETE FROM").matcher(s).results().count();
        long limits = Pattern.compile(":lim").matcher(s).results().count();
        assertTrue(deletes > 0 && limits >= deletes, "Her DELETE :lim ile sinirli olmali");
    }
}
