package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * Hiz siniri kapsami (T-060, CLAUDE.md guvenlik kurali 4: yazma uclarinda rate limit zorunlu).
 *
 * <p>Kaynak taramasi: her {@code @RestController} sinifinda POST/PUT/PATCH/DELETE eslemeli, yonetici olmayan (yol/sinif
 * adinda "admin" yok; yonetici uclari RBAC + denetimle korunur) metodun GOVDESINDE {@code limiter}/{@code RateLimit}
 * gecmeli. Limit servis katmaninda uygulanan eski uclar {@code ratelimit-coverage-baseline.txt} listesindedir; liste
 * yalnizca KUCULUR: yeni limitsiz yazma ucu testi kirar, listedeki bir uc kapsandiginda ya da kalktiginda listeden
 * silinebilir. Yeni uc eklerken listeye eklemek yerine controller'da {@code limiter.check} cagirin.
 */
class RateLimitCoverageTest {

    private static final Path SRC = Paths.get("src", "main", "java");
    private static final Pattern WRITE_MAPPING = Pattern.compile("@(Post|Put|Patch|Delete)Mapping");
    private static final Pattern ANY_MAPPING = Pattern.compile("@(Get|Post|Put|Patch|Delete)Mapping");
    private static final Pattern LIMITED = Pattern.compile("limiter|ratelimit|rateLimiter", Pattern.CASE_INSENSITIVE);

    /** T-060 kapsamindaki uclar: controller govdesinde limiter olmak ZORUNDA (baseline'a eklenemez). */
    private static final Set<String> MUST_BE_LIMITED = Set.of(
            "BlockController#block", "BlockController#unblock", "LegalController#accept",
            "ProfileController#update", "ProfileController#get", "FollowController#follow",
            "FeedbackController#unvote", "TicketController#close", "NotificationController#list",
            "BookmarkController#list", "BookmarkController#ids", "AuthController#logout");

    /** Controller metodlarinin ( "Sinif#metod" ) govdesinde limiter var mi; yonetici uclari haric. */
    private static java.util.Map<String, Boolean> scan(Pattern mapping) throws IOException {
        java.util.Map<String, Boolean> out = new java.util.TreeMap<>();
        List<Path> files;
        try (Stream<Path> w = Files.walk(SRC)) {
            files = w.filter(p -> p.toString().endsWith(".java")).collect(Collectors.toList());
        }
        for (Path f : files) {
            String s = Files.readString(f, StandardCharsets.UTF_8);
            if (!s.contains("@RestController")) {
                continue;
            }
            String cls = f.getFileName().toString().replace(".java", "");
            if (cls.toLowerCase().contains("admin")) {
                continue;
            }
            Matcher cm = Pattern.compile("@RequestMapping\\(([^)]*)\\)").matcher(s);
            String base = cm.find() ? cm.group(1) : "";
            if (base.contains("/admin")) {
                continue;
            }
            Matcher m = mapping.matcher(s);
            while (m.find()) {
                int ann = m.start();
                int sig = s.indexOf("public ", ann);
                if (sig < 0) {
                    continue;
                }
                String annotations = s.substring(ann, sig);
                if (annotations.contains("/admin")) {
                    continue;
                }
                int open = s.indexOf('{', sig);
                int depth = 0;
                int end = open;
                for (; end < s.length(); end++) {
                    char c = s.charAt(end);
                    if (c == '{') {
                        depth++;
                    } else if (c == '}' && --depth == 0) {
                        break;
                    }
                }
                String signature = s.substring(sig, open);
                Matcher nm = Pattern.compile("(\\w+)\\s*\\(").matcher(signature);
                if (!nm.find()) {
                    continue;
                }
                String body = s.substring(open, end);
                out.merge(cls + "#" + nm.group(1), LIMITED.matcher(body).find(), Boolean::logicalAnd);
            }
        }
        return out;
    }

    private static Set<String> baseline() throws IOException {
        Set<String> b = new TreeSet<>();
        try (var in = RateLimitCoverageTest.class.getResourceAsStream("/ratelimit-coverage-baseline.txt")) {
            assertTrue(in != null, "ratelimit-coverage-baseline.txt bulunamadi");
            for (String line : new String(in.readAllBytes(), StandardCharsets.UTF_8).split("\\R")) {
                String t = line.strip();
                if (!t.isEmpty() && !t.startsWith("#")) {
                    b.add(t);
                }
            }
        }
        return b;
    }

    @Test
    void t060EndpointsCallLimiterInController() throws IOException {
        var scan = scan(ANY_MAPPING); // GET uclari (profil, bildirim, yer imi) dahil
        List<String> missing = new ArrayList<>();
        for (String id : MUST_BE_LIMITED) {
            if (!Boolean.TRUE.equals(scan.get(id))) {
                missing.add(id);
            }
        }
        assertEquals(List.of(), missing, "Bu uclarda controller govdesinde limiter.check olmali");
    }

    @Test
    void noNewUnlimitedWriteEndpoints() throws IOException {
        var scan = scan(WRITE_MAPPING);
        Set<String> offenders = scan.entrySet().stream().filter(e -> !e.getValue()).map(java.util.Map.Entry::getKey)
                .collect(Collectors.toCollection(TreeSet::new));
        Set<String> base = baseline();

        Set<String> fresh = new TreeSet<>(offenders);
        fresh.removeAll(base);
        assertEquals(Set.of(), fresh, "Limitsiz yeni yazma ucu: controller'da limiter.check cagirin "
                + "(baseline'a eklemek son care ve gerekcelendirilmeli)");

        // Kapsanan/kalkan uc baseline'da kalmis olabilir (baska is akislari paralel limit ekler): kirmaz, bildirir.
        Set<String> stale = new TreeSet<>(base);
        stale.removeAll(offenders);
        if (!stale.isEmpty()) {
            System.out.println("[RateLimitCoverageTest] baseline'dan silinebilir (artik limitli/kalkmis): " + stale);
        }
    }
}
