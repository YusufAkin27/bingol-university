package edu.bingol.backend.moderation.profanity;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.List;
import java.util.Locale;
import org.springframework.data.domain.PageRequest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Uygunsuz ifade filtresi yonetimi (yalnizca ADMIN; yazma istekleri AuditInterceptor ile denetlenir).
 * Yerlesik liste kaynak dosyadadir ve silinemez; burada yalnizca yonetici BLOCK/ALLOW kayitlari yonetilir.
 */
@RestController
@RequestMapping("/api/admin/profanity")
public class ProfanityAdminController {

    /** lang: TR | EN | AR | KU (Kurtce) | ALL; category bos = PROFANITY (T-059). */
    public record TermRequest(@NotBlank @Size(max = 80) String term, @NotNull ProfanityTerm.Kind kind,
                              @Pattern(regexp = "(?i)TR|EN|AR|KU|ALL") String lang, @Size(max = 200) String note,
                              ProfanityCategory category) {
        /** Kategorisiz (eski) istemci / test cagrilari: PROFANITY. */
        public TermRequest(String term, ProfanityTerm.Kind kind, String lang, String note) {
            this(term, kind, lang, note, null);
        }
    }

    public record BulkRequest(@NotBlank @Size(max = 20000) String text, @NotNull ProfanityTerm.Kind kind,
                              @Pattern(regexp = "(?i)TR|EN|AR|KU|ALL") String lang, ProfanityCategory category) {
        public BulkRequest(String text, ProfanityTerm.Kind kind, String lang) {
            this(text, kind, lang, null);
        }
    }

    public record CheckRequest(@NotBlank @Size(max = 20000) String text) {}

    public record TermView(Long id, String term, ProfanityTerm.Kind kind, String lang, String note, Long createdBy,
                           Instant createdAt, ProfanityCategory category) {
        static TermView of(ProfanityTerm t) {
            return new TermView(t.getId(), t.getTerm(), t.getKind(), t.getLang(), t.getNote(), t.getCreatedBy(),
                    t.getCreatedAt(), t.getCategory());
        }
    }

    public record TermPage(List<TermView> items, Long nextCursor) {}

    public record BulkResult(int added, int skipped, int invalid) {}

    public record CheckResult(boolean blocked, List<String> matches, String normalized, ProfanityCategory category) {}

    public record Settings(boolean enabled, String mode) {}

    public record Info(ProfanityFilter.BuiltIn builtIn, long adminBlock, long adminAllow, Settings settings,
                       Map<ProfanityCategory, Integer> builtInByCategory, Map<ProfanityCategory, Long> adminByCategory) {}

    public record StatRow(String entity, String field, long count) {}

    /** byCategory: kategori -> engelleme sayisi (periyodik gozden gecirme; T-059). */
    public record StatWindow(long total, List<StatRow> byField, Map<String, Long> byCategory) {}

    public record Stats(StatWindow last24h, StatWindow last7d) {}

    private final ProfanityTermRepository repo;
    private final ProfanityFilter filter;
    private final ProfanityHitLogRepository hits;
    private final ProfanityProperties props;
    private final RateLimiter limiter;

    public ProfanityAdminController(ProfanityTermRepository repo, ProfanityFilter filter,
                                    ProfanityHitLogRepository hits, ProfanityProperties props, RateLimiter limiter) {
        this.repo = repo;
        this.filter = filter;
        this.hits = hits;
        this.props = props;
        this.limiter = limiter;
    }

    @GetMapping
    public TermPage list(@RequestParam(defaultValue = "BLOCK") ProfanityTerm.Kind kind,
                         @RequestParam(required = false) String q, @RequestParam(required = false) Long cursor,
                         @RequestParam(defaultValue = "50") int size) {
        int s = CursorPage.clampSize(size);
        String pattern = q == null || q.isBlank() ? "" : "%" + q.trim().toLowerCase(Locale.ROOT)
                .replace("!", "!!").replace("%", "!%").replace("_", "!_") + "%";
        CursorPage<TermView> p = CursorPage.of(repo.page(kind, pattern, cursor, PageRequest.of(0, s + 1)), s,
                ProfanityTerm::getId, TermView::of);
        return new TermPage(p.items(), p.nextCursor());
    }

    @GetMapping("/info")
    public Info info() {
        Map<ProfanityCategory, Long> admin = new EnumMap<>(ProfanityCategory.class);
        for (ProfanityCategory c : ProfanityCategory.values()) {
            admin.put(c, repo.countByKindAndCategory(ProfanityTerm.Kind.BLOCK, c));
        }
        return new Info(filter.builtIn(), repo.countByKind(ProfanityTerm.Kind.BLOCK),
                repo.countByKind(ProfanityTerm.Kind.ALLOW), new Settings(props.enabled(), props.mode().name()),
                filter.builtInCategoryCounts(), admin);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public TermView add(@Valid @RequestBody TermRequest r, Authentication auth) {
        Long admin = adminId(auth);
        limiter.check("prof:w:" + key(admin), 60, Duration.ofMinutes(1));
        ProfanityTerm t = create(r.term(), r.kind(), r.lang(), r.note(), admin, r.category());
        filter.refresh();
        return TermView.of(t);
    }

    /** Satir satir toplu ekleme (en fazla 500 satir); gecersiz/tekrar satirlar atlanir. */
    @PostMapping("/bulk")
    @Transactional
    public BulkResult bulk(@Valid @RequestBody BulkRequest r, Authentication auth) {
        Long admin = adminId(auth);
        limiter.check("prof:w:" + key(admin), 60, Duration.ofMinutes(1));
        String[] lines = r.text().split("\\R");
        if (lines.length > 500) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En fazla 500 satır eklenebilir.");
        }
        int added = 0;
        int skipped = 0;
        int invalid = 0;
        for (String line : lines) {
            if (line.isBlank() || line.strip().startsWith("#")) {
                continue;
            }
            try {
                create(line.strip(), r.kind(), r.lang(), null, admin, r.category());
                added++;
            } catch (ApiException e) {
                if ("PROFANITY_TERM_EXISTS".equals(e.code())) {
                    skipped++;
                } else {
                    invalid++;
                }
            }
        }
        filter.refresh();
        return new BulkResult(added, skipped, invalid);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void remove(@PathVariable Long id, Authentication auth) {
        limiter.check("prof:w:" + key(adminId(auth)), 60, Duration.ofMinutes(1));
        if (!repo.existsById(id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "PROFANITY_TERM_NOT_FOUND", "Kelime kaydı bulunamadı.");
        }
        repo.deleteById(id);
        filter.refresh();
    }

    /** Test kutusu: eslesmeyi YALNIZCA yoneticiye gosterir. */
    @PostMapping("/check")
    public CheckResult check(@Valid @RequestBody CheckRequest r, Authentication auth) {
        limiter.check("prof:c:" + key(adminId(auth)), 120, Duration.ofMinutes(1));
        ProfanityMatcher.Result res = filter.check(r.text());
        return new CheckResult(res.blocked(), res.matches(), filter.normalized(r.text()),
                res.blocked() ? filter.categoryOf(res) : null);
    }

    @GetMapping("/stats")
    public Stats stats() {
        Instant now = Instant.now();
        return new Stats(window(now.minus(Duration.ofHours(24))), window(now.minus(Duration.ofDays(7))));
    }

    /** Yoneticinin ekledikleri (CSV; hucre kacisli). */
    @GetMapping("/export.csv")
    public ResponseEntity<byte[]> export(@RequestParam(required = false) ProfanityTerm.Kind kind) {
        List<ProfanityTerm> rows = kind == null ? repo.findAllByOrderByIdAsc() : repo.findByKindOrderByIdAsc(kind);
        StringBuilder sb = new StringBuilder("term,kind,lang,category,note,createdAt\n");
        for (ProfanityTerm t : rows) {
            sb.append(cell(t.getTerm())).append(',').append(t.getKind()).append(',').append(t.getLang()).append(',')
                    .append(t.getCategory()).append(',')
                    .append(cell(t.getNote())).append(',').append(t.getCreatedAt()).append('\n');
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"profanity-terms.csv\"")
                .contentType(MediaType.parseMediaType("text/csv;charset=UTF-8"))
                .body(sb.toString().getBytes(StandardCharsets.UTF_8));
    }

    // ---- yardimcilar ----

    private ProfanityTerm create(String raw, ProfanityTerm.Kind kind, String lang, String note, Long admin,
                                 ProfanityCategory category) {
        String term = raw == null ? "" : raw.strip();
        String canon = ProfanityMatcher.canonical(term);
        if (term.length() < 2 || term.length() > 80 || canon == null || canon.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PROFANITY_TERM_INVALID",
                    "Kelime geçersiz: 2-80 karakter, en az bir harf içermeli.");
        }
        if (repo.existsByKindAndTermNormalized(kind, canon)) {
            throw new ApiException(HttpStatus.CONFLICT, "PROFANITY_TERM_EXISTS", "Bu kelime listede zaten var.");
        }
        ProfanityTerm t = new ProfanityTerm();
        t.setTerm(term);
        t.setTermNormalized(canon);
        t.setKind(kind);
        t.setCategory(category == null ? ProfanityCategory.PROFANITY : category);
        t.setLang(lang == null || lang.isBlank() ? "ALL" : lang.toUpperCase(Locale.ROOT));
        t.setNote(note == null || note.isBlank() ? null : note.strip());
        t.setCreatedBy(admin);
        try {
            return repo.saveAndFlush(t);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "PROFANITY_TERM_EXISTS", "Bu kelime listede zaten var.");
        }
    }

    private StatWindow window(Instant since) {
        List<StatRow> rows = new ArrayList<>();
        long total = 0;
        for (Object[] r : hits.countsSince(since)) {
            long c = ((Number) r[2]).longValue();
            rows.add(new StatRow((String) r[0], (String) r[1], c));
            total += c;
        }
        Map<String, Long> byCategory = new LinkedHashMap<>();
        for (Object[] r : hits.countsByCategorySince(since)) {
            byCategory.put((String) r[0], ((Number) r[1]).longValue());
        }
        return new StatWindow(total, rows, byCategory);
    }

    private static String cell(String v) {
        if (v == null) {
            return "";
        }
        String s = v;
        if (!s.isEmpty() && "=+-@\t\r".indexOf(s.charAt(0)) >= 0) {
            s = "'" + s; // CSV enjeksiyonu
        }
        return '"' + s.replace("\"", "\"\"") + '"';
    }

    private static Long adminId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }

    private static String key(Long adminId) {
        return adminId == null ? "basic" : adminId.toString();
    }
}
