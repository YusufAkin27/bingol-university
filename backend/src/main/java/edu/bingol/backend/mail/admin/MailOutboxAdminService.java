package edu.bingol.backend.mail.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRepository;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.mail.MailCategory;
import edu.bingol.backend.mail.MailOutbox;
import edu.bingol.backend.mail.MailStatus;
import edu.bingol.backend.mail.MailSuppressionService;
import edu.bingol.backend.mail.MailTemplate;
import edu.bingol.backend.mail.admin.MailOpsDtos.BulkFailure;
import edu.bingol.backend.mail.admin.MailOpsDtos.BulkResult;
import edu.bingol.backend.mail.admin.MailOpsDtos.OutboxDetail;
import edu.bingol.backend.mail.admin.MailOpsDtos.OutboxRow;
import edu.bingol.backend.mail.admin.MailOpsDtos.PageResult;
import edu.bingol.backend.mail.admin.MailOpsDtos.TimelineEvent;
import edu.bingol.backend.observability.LogMasking;
import jakarta.persistence.criteria.Predicate;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Mail kuyrugu yonetimi (P13): arama/ayrinti, tek ve toplu yeniden deneme/iptal. Alici adresi her yerde MASKELI doner;
 * icerik ve degiskenler (kod/jeton icerebilir) HICBIR yanitta yoktur. Durum gecisleri atomik UPDATE'tir.
 *
 * <p>Yeniden deneme guvenli olmayi tercih eder: kayit DEAD/SKIPPED olurken degiskenleri silindigi icin (KVKK) icerik
 * yeniden uretilemiyorsa (kod postasi, duyuru, ozel sablon...) deneme REDDEDILIR (409) — bos/yanlis posta gitmez.
 */
@Service
public class MailOutboxAdminService {

    private static final Logger log = LoggerFactory.getLogger(MailOutboxAdminService.class);

    public static final int MAX_BULK = 200;
    /** MailQueueWorker.CODE_MAIL_MAX_AGE ile ayni (kod 10 dk gecerli). */
    static final Duration CODE_MAX_AGE = Duration.ofMinutes(10);
    private static final Pattern DIGITS = Pattern.compile("^[0-9]{1,18}$");
    private static final Set<MailTemplate> CODE_TEMPLATES =
            Set.of(MailTemplate.VERIFICATION_CODE, MailTemplate.PASSWORD_RESET_CODE);
    private static final Set<MailStatus> RETRY_FROM = Set.of(MailStatus.DEAD, MailStatus.SKIPPED);
    private static final Set<MailStatus> CANCEL_FROM = Set.of(MailStatus.PENDING, MailStatus.FAILED);
    public static final String CANCEL_NOTE = "yonetici iptal etti";

    private final MailOutboxQueryRepository repo;
    private final MailSuppressionService suppression;
    private final AuditRepository audit;

    public MailOutboxAdminService(MailOutboxQueryRepository repo, MailSuppressionService suppression,
                                  AuditRepository audit) {
        this.repo = repo;
        this.suppression = suppression;
        this.audit = audit;
    }

    // ------------------------------------------------------------------ liste

    /** q: tam e-posta (buyuk/kucuk harf duyarsiz), '@alan' (alan eki) ya da kayit numarasi. */
    @Transactional(readOnly = true)
    public PageResult<OutboxRow> list(MailStatus status, MailTemplate template, MailCategory category, String q,
                                      Instant from, Instant toExclusive, int page, int size) {
        Specification<MailOutbox> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (status != null) {
                ps.add(cb.equal(root.get("status"), status));
            }
            if (template != null) {
                ps.add(cb.equal(root.get("template"), template));
            }
            if (category != null) {
                ps.add(cb.equal(root.get("priority"), category.priority()));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), from));
            }
            if (toExclusive != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), toExclusive));
            }
            String t = q == null ? "" : q.trim().toLowerCase(Locale.ROOT);
            if (!t.isEmpty()) {
                if (t.startsWith("@") && t.length() > 3) {
                    ps.add(cb.like(cb.lower(root.<String>get("toAddress")), "%" + escapeLike(t), '\\'));
                } else if (t.indexOf('@') > 0) {
                    ps.add(cb.equal(cb.lower(root.<String>get("toAddress")), t));
                } else if (DIGITS.matcher(t).matches()) {
                    ps.add(cb.equal(root.get("id"), Long.parseLong(t)));
                } else {
                    ps.add(cb.disjunction());
                }
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        int s = Math.min(Math.max(size, 1), 100);
        Page<MailOutbox> res = repo.findAll(spec,
                PageRequest.of(Math.max(page, 0), s, Sort.by(Sort.Direction.DESC, "id")));
        Instant now = Instant.now();
        return PageResult.of(res.getContent().stream().map(m -> row(m, now)).toList(), res.getNumber(), s,
                res.getTotalElements());
    }

    private static String escapeLike(String t) {
        return t.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    private OutboxRow row(MailOutbox m, Instant now) {
        return new OutboxRow(m.getId(), m.getStatus().name(), m.getTemplate().name(),
                MailCategory.of(m.getTemplate()).name(), LogMasking.email(m.getToAddress()), m.getLang(),
                m.getAttempts(), iso(m.getNextAttemptAt()), iso(m.getCreatedAt()), iso(m.getSentAt()),
                LogMasking.scrub(m.getLastError()), retryBlock(m, now) == null && RETRY_FROM.contains(m.getStatus()),
                CANCEL_FROM.contains(m.getStatus()));
    }

    // ------------------------------------------------------------------ ayrinti

    @Transactional(readOnly = true)
    public OutboxDetail detail(Long id) {
        MailOutbox m = find(id);
        Instant now = Instant.now();
        String block = retryBlock(m, now);
        boolean retryable = RETRY_FROM.contains(m.getStatus()) && block == null;
        List<String> warnings = new ArrayList<>();
        if (CODE_TEMPLATES.contains(m.getTemplate())) {
            warnings.add("CODE_MAIL");
        }
        if (m.getStatus() == MailStatus.SKIPPED && m.getLastError() != null
                && m.getLastError().contains("bastirma")) {
            warnings.add("SUPPRESSED");
        }
        return new OutboxDetail(m.getId(), m.getStatus().name(), m.getTemplate().name(),
                MailCategory.of(m.getTemplate()).name(), LogMasking.email(m.getToAddress()), m.getLang(),
                m.getAttempts(), iso(m.getNextAttemptAt()), iso(m.getCreatedAt()), iso(m.getSentAt()),
                LogMasking.scrub(m.getLastError()), retryable, RETRY_FROM.contains(m.getStatus()) ? block : null,
                CANCEL_FROM.contains(m.getStatus()), contentCleared(m), false, timeline(m), warnings);
    }

    /** Elde olan zaman damgalarindan turetilmis gecmis + yoneticinin bu kayitta yaptigi islemler (denetim kaydi). */
    private List<TimelineEvent> timeline(MailOutbox m) {
        List<TimelineEvent> out = new ArrayList<>();
        out.add(new TimelineEvent(iso(m.getCreatedAt()), "CREATED", null));
        if (m.getAttempts() > 0) {
            out.add(new TimelineEvent(null, "ATTEMPTS", String.valueOf(m.getAttempts())));
        }
        if (m.getSentAt() != null) {
            out.add(new TimelineEvent(iso(m.getSentAt()), "SENT", null));
        }
        if (m.getStatus() == MailStatus.PENDING || m.getStatus() == MailStatus.FAILED) {
            out.add(new TimelineEvent(iso(m.getNextAttemptAt()), "NEXT_ATTEMPT", null));
        } else if (m.getStatus() == MailStatus.DEAD || m.getStatus() == MailStatus.SKIPPED) {
            out.add(new TimelineEvent(null, m.getStatus().name(), LogMasking.scrub(m.getLastError())));
        }
        try {
            audit.page(new AuditRepository.Filter(null, null, null, null, null, "MAIL_OUTBOX",
                    String.valueOf(m.getId()), null), 0, 20).stream()
                    .filter(a -> a.status() < 400 && !"GET".equals(a.method()))
                    .forEach(a -> out.add(new TimelineEvent(a.at(),
                            "ADMIN_ACTION", LogMasking.scrub(a.summary()))));
        } catch (RuntimeException e) {
            log.debug("Kuyruk kaydi denetim gecmisi okunamadi: {}", e.toString());
        }
        return out;
    }

    // ------------------------------------------------------------------ yeniden dene

    /** Hata kodu (MAILOPS_RETRY_*) ya da null (denenebilir). Durum kontrolu cagirana dahil. */
    String retryBlock(MailOutbox m, Instant now) {
        if (!RETRY_FROM.contains(m.getStatus())) {
            return "MAILOPS_RETRY_STATE";
        }
        boolean code = CODE_TEMPLATES.contains(m.getTemplate());
        if (code && m.getCreatedAt() != null && m.getCreatedAt().isBefore(now.minus(CODE_MAX_AGE))) {
            return "MAILOPS_RETRY_STALE_CODE";
        }
        if (contentCleared(m)) {
            return "MAILOPS_RETRY_NO_CONTENT";
        }
        if (MailCategory.of(m.getTemplate()) == MailCategory.ANNOUNCEMENT && suppression.isSuppressed(m.getToAddress())) {
            return "MAILOPS_RETRY_SUPPRESSED";
        }
        return null;
    }

    /** Icerik yeniden uretilemez mi: degiskenler silinmis ve sablon degisken gerektiriyor (ACCOUNT_DELETED gerektirmez). */
    static boolean contentCleared(MailOutbox m) {
        String v = m.getVarsJson();
        boolean empty = v == null || v.isBlank() || "{}".equals(v.trim());
        return empty && m.getTemplate() != MailTemplate.ACCOUNT_DELETED;
    }

    @Transactional
    public OutboxDetail retry(Long id) {
        MailOutbox m = find(id);
        AuditContext.target("MAIL_OUTBOX", id).summary("yeniden denendi: " + m.getTemplate() + " onceki=" + m.getStatus());
        retryOne(m);
        return detail(id);
    }

    private void retryOne(MailOutbox m) {
        String block = retryBlock(m, Instant.now());
        if (block != null) {
            throw blocked(block);
        }
        if (repo.requeue(m.getId(), RETRY_FROM, Instant.now()) == 0) {
            throw blocked("MAILOPS_RETRY_STATE");
        }
    }

    private static ApiException blocked(String code) {
        return switch (code) {
            case "MAILOPS_RETRY_STALE_CODE" -> new ApiException(HttpStatus.CONFLICT, code,
                    "Eski kod postası: kod yalnızca 10 dakika geçerlidir; kullanıcı yeni kod istemelidir.");
            case "MAILOPS_RETRY_NO_CONTENT" -> new ApiException(HttpStatus.CONFLICT, code,
                    "Posta içeriği gizlilik gereği silindiği için yeniden üretilemez.");
            case "MAILOPS_RETRY_SUPPRESSED" -> new ApiException(HttpStatus.CONFLICT, code,
                    "Adres bastırma listesinde: duyuru yeniden gönderilmez.");
            default -> new ApiException(HttpStatus.CONFLICT, "MAILOPS_RETRY_STATE",
                    "Yalnızca ölü (DEAD) ya da atlanmış (SKIPPED) kayıt yeniden denenebilir.");
        };
    }

    // ------------------------------------------------------------------ iptal

    @Transactional
    public OutboxDetail cancel(Long id) {
        MailOutbox m = find(id);
        AuditContext.target("MAIL_OUTBOX", id).summary("iptal edildi: " + m.getTemplate() + " onceki=" + m.getStatus());
        cancelOne(m);
        return detail(id);
    }

    private void cancelOne(MailOutbox m) {
        if (repo.cancel(m.getId(), CANCEL_FROM, CANCEL_NOTE) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "MAILOPS_CANCEL_STATE",
                    "Yalnızca bekleyen (PENDING/FAILED) kayıt iptal edilebilir.");
        }
    }

    // ------------------------------------------------------------------ toplu

    /** Kismi basari: her kimlik kendi basina denenir; hatalar kodlariyla doner. Tum islem tek denetim satiridir. */
    public BulkResult bulk(String action, List<Long> ids) {
        String a = action == null ? "" : action.trim().toUpperCase(Locale.ROOT);
        if (!a.equals("RETRY") && !a.equals("CANCEL")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAILOPS_BULK_INVALID",
                    "Toplu işlem RETRY ya da CANCEL olmalı ve en çok " + MAX_BULK + " kayıt içermelidir.",
                    String.valueOf(MAX_BULK));
        }
        Set<Long> unique = ids == null ? Set.of() : new LinkedHashSet<>(ids);
        unique.remove(null);
        if (unique.isEmpty() || unique.size() > MAX_BULK) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAILOPS_BULK_INVALID",
                    "Toplu işlem RETRY ya da CANCEL olmalı ve en çok " + MAX_BULK + " kayıt içermelidir.",
                    String.valueOf(MAX_BULK));
        }
        List<BulkFailure> failed = new ArrayList<>();
        int ok = 0;
        for (Long id : unique) {
            try {
                MailOutbox m = repo.findById(id).orElse(null);
                if (m == null) {
                    failed.add(new BulkFailure(id, "MAILOPS_OUTBOX_NOT_FOUND"));
                    continue;
                }
                if (a.equals("RETRY")) {
                    retryOne(m);
                } else {
                    cancelOne(m);
                }
                ok++;
            } catch (ApiException e) {
                failed.add(new BulkFailure(id, e.code()));
            }
        }
        AuditContext.target("MAIL_OUTBOX", null).summary("toplu " + a + ": istenen=" + unique.size() + " basarili=" + ok
                + " basarisiz=" + failed.size());
        return new BulkResult(a, unique.size(), ok, failed);
    }

    private MailOutbox find(Long id) {
        return repo.findById(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "MAILOPS_OUTBOX_NOT_FOUND", "Kuyruk kaydı bulunamadı."));
    }

    private static String iso(Instant t) {
        return t == null ? null : t.toString();
    }
}
