package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ReportService {

    private static final Logger log = LoggerFactory.getLogger(ReportService.class);

    /** Rapor kisiti isareti (Redis, TTL = restrict-days). */
    public static final String RESTRICT_KEY_PREFIX = "modrestrict:";

    private final ReportRepository reports;
    private final Map<ReportTargetType, ReportTargetHandler> handlers = new EnumMap<>(ReportTargetType.class);
    private final UserModerationService userModeration;
    private final ModerationNotifier notifier;
    private final ModerationTargetStateRepository states;
    private final StrikeService strikes;
    private final ModerationProperties props;
    private final StringRedisTemplate redis;

    public ReportService(ReportRepository reports, List<ReportTargetHandler> handlerBeans,
                         UserModerationService userModeration, ModerationNotifier notifier,
                         ModerationTargetStateRepository states, StrikeService strikes, ModerationProperties props,
                         StringRedisTemplate redis) {
        this.reports = reports;
        this.userModeration = userModeration;
        this.notifier = notifier;
        this.states = states;
        this.strikes = strikes;
        this.props = props;
        this.redis = redis;
        handlerBeans.forEach(h -> handlers.put(h.type(), h));
    }

    @Transactional
    public Report create(Long reporterId, CreateReportRequest r) {
        if (Boolean.TRUE.equals(redis.hasKey(RESTRICT_KEY_PREFIX + reporterId))) {
            throw new ApiException(HttpStatus.FORBIDDEN, "REPORTING_RESTRICTED",
                    "Çok sayıda reddedilen rapor nedeniyle geçici olarak rapor gönderemezsiniz.");
        }
        ReportTargetHandler h = handler(r.targetType());
        if (!h.exists(r.targetId())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "TARGET_NOT_FOUND", "Raporlanan içerik bulunamadı.");
        }
        Optional<Long> owner = h.ownerId(r.targetId());
        if (owner.filter(reporterId::equals).isPresent()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_REPORT_SELF", "Kendi içeriğinizi raporlayamazsınız.");
        }
        if (reports.existsByReporterIdAndTargetTypeAndTargetIdAndStatus(reporterId, r.targetType(), r.targetId(),
                Report.Status.OPEN)
                || reports.existsByReporterIdAndTargetTypeAndTargetIdAndCreatedAtAfter(reporterId, r.targetType(),
                r.targetId(), Instant.now().minus(Duration.ofDays(props.reReportBlockDays())))) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_REPORTED", "Bu içeriği zaten raporladınız.");
        }
        Report report = new Report();
        report.setReporterId(reporterId);
        report.setTargetType(r.targetType());
        report.setTargetId(r.targetId());
        report.setReason(r.reason());
        report.setNote(r.note() == null || r.note().isBlank() ? null : r.note().trim());
        report = reports.save(report);

        applyPolicy(report, h, owner);
        return report;
    }

    /** Oncelik hesabi + (geri alinabilir turlerde) esik asildiysa otomatik gecici gizleme. */
    private void applyPolicy(Report report, ReportTargetHandler h, Optional<Long> owner) {
        ReportTargetType type = report.getTargetType();
        Long id = report.getTargetId();
        boolean hidden = states.findByTargetTypeAndTargetId(type, id).filter(s -> s.getHiddenBy() != null).isPresent();
        int threshold = props.autoHideThreshold();
        if (!hidden && threshold > 0 && h.reversible()) {
            Instant cutoff = Instant.now().minus(Duration.ofHours(props.newAccountMinAgeHours()));
            if (reports.countEligibleOpenReporters(type, id, cutoff) >= threshold) {
                h.hide(id);
                states.markHidden(type.name(), id, ModerationTargetState.HiddenBy.AUTO.name());
                hidden = true;
                owner.ifPresent(uid -> notifier.autoHidden(uid, type, id));
                log.info("Otomatik gizleme: {} #{} (esik {})", type, id, threshold);
            }
        }
        int priority = (int) reports.countOpenReporters(type, id) * 10 + (hidden ? 100 : 0);
        reports.updateOpenPriority(type, id, priority);
        report.setPriority(priority);
    }

    public List<Report> queue(Report.Status status, Long cursor, int size) {
        return queue(status, null, cursor, size, false);
    }

    public List<Report> queue(Report.Status status, Long cursor, int size, boolean newestFirst) {
        return queue(status, null, cursor, size, newestFirst);
    }

    public List<Report> queue(Report.Status status, ReportTargetType type, Long cursor, int size, boolean newestFirst) {
        PageRequest page = PageRequest.of(0, size + 1);
        return newestFirst ? reports.queueNewestFirst(status, type, cursor, page)
                : reports.queue(status, type, cursor, page);
    }

    /** Oncelik sirali kuyruk; sayfa numarasi tabanli (cursor = sayfa). */
    public Slice<Report> queueByPriority(Report.Status status, ReportTargetType type, int page, int size) {
        return reports.queueByPriority(status, type, PageRequest.of(Math.max(page, 0), size));
    }

    /** Kuyruk satiri icin zenginlestirme: onizleme, gizlenme durumu, farkli raporlayici sayisi. */
    public Enrichment enrich(Report r) {
        ReportTargetHandler h = handlers.get(r.getTargetType());
        MediaPreview preview = null;
        if (h != null) {
            try {
                preview = h.preview(r.getTargetId()).orElse(null);
            } catch (RuntimeException e) {
                log.warn("Onizleme alinamadi {} #{}: {}", r.getTargetType(), r.getTargetId(), e.toString());
            }
        }
        Optional<ModerationTargetState> st = states.findByTargetTypeAndTargetId(r.getTargetType(), r.getTargetId());
        return new Enrichment(preview, st.map(s -> s.getHiddenBy() != null).orElse(false),
                st.map(s -> s.getHiddenBy() == null ? null : s.getHiddenBy().name()).orElse(null),
                reports.countOpenReporters(r.getTargetType(), r.getTargetId()));
    }

    public record Enrichment(MediaPreview preview, boolean hidden, String hiddenBy, long openReporters) {}

    /** Karar, ayni hedefe bekleyen tum raporlari kapatir. */
    @Transactional
    public void resolve(Long reportId, Long adminId, Report.Resolution action, String message) {
        resolve(reportId, adminId, action, message, null);
    }

    @Transactional
    public void resolve(Long reportId, Long adminId, Report.Resolution action, String message, String reasonCode) {
        if (reasonCode != null && !reasonCode.isBlank() && DecisionReason.parse(reasonCode).isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_CODE_INVALID", "Geçersiz karar nedeni kodu.");
        }
        String code = DecisionReason.parse(reasonCode).map(Enum::name).orElse(null);
        Report report = reports.findById(reportId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "REPORT_NOT_FOUND", "Rapor bulunamadı."));
        if (report.getStatus() == Report.Status.RESOLVED) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_RESOLVED", "Rapor zaten sonuçlandırılmış.");
        }
        ReportTargetType type = report.getTargetType();
        Long targetId = report.getTargetId();
        ReportTargetHandler h = handler(type);
        boolean exists = h.exists(targetId);
        Optional<Long> owner = exists ? h.ownerId(targetId) : Optional.empty();
        Optional<ModerationTargetState> state = states.findByTargetTypeAndTargetId(type, targetId);
        boolean autoHidden = state.map(s -> s.getHiddenBy() == ModerationTargetState.HiddenBy.AUTO).orElse(false);

        // Mesaj/neden: yonetici mesaji oncelikli, yoksa alici dilinde sablon metni
        String adminText = message == null || message.isBlank() ? null : message;
        switch (action) {
            case DISMISS -> {
                if (autoHidden && exists && h.reversible()) {
                    h.unhide(targetId);
                    owner.ifPresent(uid -> notifier.restored(uid, type, targetId));
                }
                if (autoHidden) {
                    states.clear(type, targetId);
                }
            }
            case WARN -> {
                // Uyari icerigi korur: otomatik gizlenmisse geri ac
                if (autoHidden && exists && h.reversible()) {
                    h.unhide(targetId);
                    states.clear(type, targetId);
                }
                owner.ifPresent(uid -> notifier.warned(uid, adminText != null ? adminText : notifier.reasonText(uid, code)));
            }
            case HIDE -> {
                if (exists) {
                    h.hide(targetId);
                    states.markHidden(type.name(), targetId, ModerationTargetState.HiddenBy.ADMIN.name());
                }
                owner.ifPresent(uid -> notifier.removed(uid, type, targetId,
                        adminText != null ? adminText : notifier.reasonText(uid, code)));
            }
            case SUSPEND_USER -> owner.ifPresent(uid -> userModeration.suspend(uid, message));
        }

        Instant now = Instant.now();
        Set<Long> reporters = new LinkedHashSet<>();
        for (Report r : reports.findByTargetTypeAndTargetIdAndStatus(type, targetId, Report.Status.OPEN)) {
            r.setStatus(Report.Status.RESOLVED);
            r.setResolution(action);
            r.setResolvedBy(adminId);
            r.setResolvedAt(now);
            r.setReasonCode(code);
            reporters.add(r.getReporterId());
        }

        if (action != Report.Resolution.DISMISS) {
            owner.ifPresent(uid -> strikes.record(uid, report, action));
        }
        boolean actioned = action != Report.Resolution.DISMISS;
        reporters.forEach(rid -> notifier.reporterOutcome(rid, actioned));
        if (!actioned) {
            reporters.forEach(this::restrictIfAbusive);
        }
    }

    /** Pencerede cok sayida reddedilen rapor yapan kullaniciya gecici rapor kisiti. */
    void restrictIfAbusive(Long reporterId) {
        int threshold = props.rejectRestrictThreshold();
        if (threshold <= 0) {
            return;
        }
        Instant since = Instant.now().minus(Duration.ofDays(props.rejectWindowDays()));
        long dismissed = reports.countByReporterIdAndResolutionAndResolvedAtAfter(reporterId, Report.Resolution.DISMISS, since);
        if (dismissed >= threshold && !Boolean.TRUE.equals(redis.hasKey(RESTRICT_KEY_PREFIX + reporterId))) {
            redis.opsForValue().set(RESTRICT_KEY_PREFIX + reporterId, "1", Duration.ofDays(props.restrictDays()));
            notifier.reporterRestricted(reporterId, props.restrictDays());
        }
    }

    private ReportTargetHandler handler(ReportTargetType type) {
        ReportTargetHandler h = handlers.get(type);
        if (h == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TARGET_TYPE_UNSUPPORTED", "Bu tür henüz raporlanamıyor.");
        }
        return h;
    }

    /** Diger servisler (itiraz) icin. */
    ReportTargetHandler handlerFor(ReportTargetType type) {
        return handler(type);
    }
}
