package edu.bingol.backend.mail.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.mail.MailCategory;
import edu.bingol.backend.mail.MailSuppression;
import edu.bingol.backend.mail.MailSuppressionService;
import edu.bingol.backend.mail.SuppressionReason;
import edu.bingol.backend.mail.admin.MailOpsDtos.PageResult;
import edu.bingol.backend.mail.admin.MailOpsDtos.SuppressionCreate;
import edu.bingol.backend.mail.admin.MailOpsDtos.SuppressionDetail;
import edu.bingol.backend.mail.admin.MailOpsDtos.SuppressionRow;
import edu.bingol.backend.observability.LogMasking;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Bastirma listesi yonetimi (P13). Adres veritabaninda DUZ degildir (yalniz SHA-256 ozeti): liste her zaman maskeli,
 * tam adres yalniz ayrintida ve yalniz bir kullanici hesabi ozetle eslesiyorsa gosterilir.
 * Kullanicinin abonelikten cikma iradesi (UNSUBSCRIBED/COMPLAINT) yonetici tarafindan zor kaldirilir: ikinci onay
 * (`X-Admin-Confirm: &lt;id&gt;`) + sebep &gt;= 20; BOUNCED/MANUAL icin sebep &gt;= 5.
 */
@Service
public class MailSuppressionAdminService {

    public static final int MAX_EXPORT_ROWS = 50_000;
    public static final int MIN_REASON = 5;
    public static final int OPT_OUT_MIN_REASON = 20;
    private static final int HASH_PREFIX = 10;
    private static final Pattern HEX64 = Pattern.compile("^[0-9a-f]{64}$");
    private static final Pattern EMAIL =
            Pattern.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}$");

    private final MailSuppressionQueryRepository repo;
    private final NamedParameterJdbcTemplate jdbc;

    public MailSuppressionAdminService(MailSuppressionQueryRepository repo, NamedParameterJdbcTemplate jdbc) {
        this.repo = repo;
        this.jdbc = jdbc;
    }

    // ------------------------------------------------------------------ liste

    @Transactional(readOnly = true)
    public PageResult<SuppressionRow> list(SuppressionReason reason, MailCategory category, String q, Instant from,
                                           Instant toExclusive, int page, int size) {
        Specification<MailSuppression> spec = spec(reason, category, q, from, toExclusive);
        int s = Math.min(Math.max(size, 1), 100);
        Page<MailSuppression> res = repo.findAll(spec,
                PageRequest.of(Math.max(page, 0), s, Sort.by(Sort.Direction.DESC, "id")));
        return PageResult.of(rows(res.getContent()), res.getNumber(), s, res.getTotalElements());
    }

    /** CSV icin: en cok {@value #MAX_EXPORT_ROWS} satir (yeniden eskiye). */
    @Transactional(readOnly = true)
    public List<SuppressionRow> exportRows(SuppressionReason reason, MailCategory category, String q, Instant from,
                                           Instant toExclusive) {
        Page<MailSuppression> res = repo.findAll(spec(reason, category, q, from, toExclusive),
                PageRequest.of(0, MAX_EXPORT_ROWS, Sort.by(Sort.Direction.DESC, "id")));
        return rows(res.getContent());
    }

    private Specification<MailSuppression> spec(SuppressionReason reason, MailCategory category, String q, Instant from,
                                                Instant toExclusive) {
        Set<String> hashes = hashesFor(q);
        return (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (reason != null) {
                ps.add(cb.equal(root.get("reason"), reason));
            }
            if (category != null) {
                ps.add(cb.equal(root.get("category"), category));
            }
            if (hashes != null) {
                // bos kume = hicbir sey eslesmez
                ps.add(hashes.isEmpty() ? cb.disjunction() : root.get("emailHash").in(hashes));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), from));
            }
            if (toExclusive != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), toExclusive));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
    }

    /**
     * `q` -> ozet kumesi (null = suzgec yok). Tam adres ('@' icerir) ve 64 haneli ozet dogrudan; baska metin (en az 3
     * karakter) kayitli kullanici adreslerinde parca aramasidir (adres bastirma tablosunda duz tutulmadigi icin).
     */
    private Set<String> hashesFor(String q) {
        if (q == null || q.isBlank()) {
            return null;
        }
        String t = q.trim().toLowerCase(Locale.ROOT);
        if (HEX64.matcher(t).matches()) {
            return Set.of(t);
        }
        if (t.indexOf('@') > 0 && t.indexOf('@') < t.length() - 1) {
            return Set.of(MailSuppressionService.hash(t));
        }
        if (t.length() < 3) {
            return Set.of();
        }
        String like = "%" + t.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        List<String> found = jdbc.queryForList("SELECT email_sha256 FROM app_user WHERE email_sha256 IS NOT NULL "
                        + "AND lower(email) LIKE :q ESCAPE '\\' LIMIT 200",
                new MapSqlParameterSource("q", like), String.class);
        return new HashSet<>(found);
    }

    private List<SuppressionRow> rows(List<MailSuppression> items) {
        Map<String, String> emails = emailsByHash(items.stream().map(MailSuppression::getEmailHash).toList());
        return items.stream().map(s -> row(s, emails.get(s.getEmailHash()))).toList();
    }

    private static SuppressionRow row(MailSuppression s, String resolvedEmail) {
        String masked = s.getEmailMasked() != null ? s.getEmailMasked()
                : resolvedEmail != null ? LogMasking.email(resolvedEmail) : null;
        return new SuppressionRow(s.getId(), masked, hashPrefix(s), s.getReason().name(), s.getCategory().name(),
                s.getNote(), s.getCreatedAt().toString(), s.getCreatedBy(), optOut(s));
    }

    private static boolean optOut(MailSuppression s) {
        return s.getReason() == SuppressionReason.UNSUBSCRIBED || s.getReason() == SuppressionReason.COMPLAINT;
    }

    private static String hashPrefix(MailSuppression s) {
        return s.getEmailHash().substring(0, Math.min(HASH_PREFIX, s.getEmailHash().length()));
    }

    /** Ozet -> kayitli kullanici adresi (yalniz yonetici ekraninda maskeleme/ayrinti icin). */
    private Map<String, String> emailsByHash(List<String> hashes) {
        Map<String, String> out = new HashMap<>();
        if (hashes.isEmpty()) {
            return out;
        }
        jdbc.query("SELECT email_sha256, email FROM app_user WHERE email_sha256 IN (:h)",
                new MapSqlParameterSource("h", hashes), rs -> {
                    out.put(rs.getString(1), rs.getString(2));
                });
        return out;
    }

    // ------------------------------------------------------------------ ayrinti

    @Transactional(readOnly = true)
    public SuppressionDetail detail(Long id) {
        MailSuppression s = find(id);
        String email = null;
        Long userId = null;
        List<Map<String, Object>> u = jdbc.queryForList("SELECT id, email FROM app_user WHERE email_sha256 = :h",
                new MapSqlParameterSource("h", s.getEmailHash()));
        if (!u.isEmpty()) {
            email = (String) u.get(0).get("email");
            userId = ((Number) u.get(0).get("id")).longValue();
        }
        String masked = s.getEmailMasked() != null ? s.getEmailMasked() : email != null ? LogMasking.email(email) : null;
        boolean optOut = optOut(s);
        return new SuppressionDetail(s.getId(), masked, email, email != null, userId, hashPrefix(s),
                s.getReason().name(), s.getCategory().name(), s.getNote(), s.getCreatedAt().toString(),
                s.getCreatedBy(), optOut, optOut ? OPT_OUT_MIN_REASON : MIN_REASON, optOut,
                warning(s.getReason()));
    }

    private static String warning(SuppressionReason r) {
        return switch (r) {
            case UNSUBSCRIBED -> "UNSUBSCRIBED";
            case COMPLAINT -> "COMPLAINT";
            default -> null;
        };
    }

    // ------------------------------------------------------------------ elle ekle

    @Transactional
    public SuppressionRow addManual(SuppressionCreate req, Long adminId) {
        if (req.reason() != null && !req.reason().isBlank()
                && !SuppressionReason.MANUAL.name().equalsIgnoreCase(req.reason().trim())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAILOPS_REASON_INVALID",
                    "Elle eklemede sebep yalnızca MANUAL olabilir.");
        }
        String note = req.note() == null ? "" : req.note().trim();
        if (note.length() < MIN_REASON) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + MIN_REASON + " karakter).", String.valueOf(MIN_REASON));
        }
        String email = req.email() == null ? "" : req.email().trim().toLowerCase(Locale.ROOT);
        if (email.length() > 254 || !EMAIL.matcher(email).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAILOPS_EMAIL_INVALID", "E-posta adresi geçersiz.");
        }
        String hash = MailSuppressionService.hash(email);
        if (repo.findByEmailHash(hash).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "MAILOPS_SUPPRESSION_EXISTS",
                    "Bu adres zaten bastırma listesinde.");
        }
        MailSuppression s = new MailSuppression();
        s.setEmailHash(hash);
        s.setReason(SuppressionReason.MANUAL);
        s.setCategory(MailCategory.ANNOUNCEMENT);
        s.setNote(note.length() > 300 ? note.substring(0, 300) : note);
        s.setEmailMasked(LogMasking.email(email));
        s.setCreatedBy(adminId);
        s.setCreatedAt(Instant.now());
        try {
            s = repo.saveAndFlush(s);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "MAILOPS_SUPPRESSION_EXISTS",
                    "Bu adres zaten bastırma listesinde.");
        }
        AuditContext.target("MAIL_SUPPRESSION", s.getId()).summary("elle bastirma eklendi: " + s.getEmailMasked());
        return row(s, email);
    }

    // ------------------------------------------------------------------ kaldir

    /**
     * Kaldirma. UNSUBSCRIBED/COMPLAINT: onay basligi bu kaydin kimligine esit olmali (yoksa 409 uyari) ve sebep &gt;= 20;
     * BOUNCED/MANUAL: sebep &gt;= 5. Kaldirma geri alinamaz; kullaniciya bildirim gitmez.
     */
    @Transactional
    public void remove(Long id, String reason, String confirm) {
        MailSuppression s = find(id);
        boolean optOut = optOut(s);
        if (optOut && (confirm == null || !confirm.trim().equals(String.valueOf(s.getId())))) {
            throw new ApiException(HttpStatus.CONFLICT, "MAILOPS_USER_OPTED_OUT",
                    "Kullanıcı kendisi çıktı: bu kayıt kaldırılırsa yeniden duyuru gönderilir.", s.getReason().name());
        }
        int min = optOut ? OPT_OUT_MIN_REASON : MIN_REASON;
        if (reason == null || reason.strip().length() < min) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + min + " karakter).", String.valueOf(min));
        }
        repo.delete(s);
        AuditContext.target("MAIL_SUPPRESSION", id).summary("bastirma kaldirildi: sebep=" + s.getReason()
                + (s.getEmailMasked() != null ? " " + s.getEmailMasked() : " ozet=" + hashPrefix(s)));
    }

    private MailSuppression find(Long id) {
        return repo.findById(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "MAILOPS_SUPPRESSION_NOT_FOUND", "Bastırma kaydı bulunamadı."));
    }
}
