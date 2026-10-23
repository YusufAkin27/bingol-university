package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.time.Instant;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ReportService {

    private final ReportRepository reports;
    private final Map<ReportTargetType, ReportTargetHandler> handlers = new EnumMap<>(ReportTargetType.class);
    private final UserModerationService userModeration;
    private final NotificationService notifications;

    public ReportService(ReportRepository reports, List<ReportTargetHandler> handlerBeans,
                         UserModerationService userModeration, NotificationService notifications) {
        this.reports = reports;
        this.userModeration = userModeration;
        this.notifications = notifications;
        handlerBeans.forEach(h -> handlers.put(h.type(), h));
    }

    @Transactional
    public Report create(Long reporterId, CreateReportRequest r) {
        ReportTargetHandler h = handler(r.targetType());
        if (!h.exists(r.targetId())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "TARGET_NOT_FOUND", "Raporlanan içerik bulunamadı.");
        }
        if (h.ownerId(r.targetId()).filter(reporterId::equals).isPresent()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_REPORT_SELF", "Kendi içeriğinizi raporlayamazsınız.");
        }
        if (reports.existsByReporterIdAndTargetTypeAndTargetIdAndStatus(reporterId, r.targetType(), r.targetId(),
                Report.Status.OPEN)) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_REPORTED", "Bu içeriği zaten raporladınız.");
        }
        Report report = new Report();
        report.setReporterId(reporterId);
        report.setTargetType(r.targetType());
        report.setTargetId(r.targetId());
        report.setReason(r.reason());
        report.setNote(r.note() == null || r.note().isBlank() ? null : r.note().trim());
        return reports.save(report);
    }

    public List<Report> queue(Report.Status status, Long cursor, int size) {
        return queue(status, cursor, size, false);
    }

    public List<Report> queue(Report.Status status, Long cursor, int size, boolean newestFirst) {
        PageRequest page = PageRequest.of(0, size + 1);
        return newestFirst ? reports.queueNewestFirst(status, cursor, page) : reports.queue(status, cursor, page);
    }

    /** Karar, ayni hedefe bekleyen tum raporlari kapatir. */
    @Transactional
    public void resolve(Long reportId, Long adminId, Report.Resolution action, String message) {
        Report report = reports.findById(reportId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "REPORT_NOT_FOUND", "Rapor bulunamadı."));
        if (report.getStatus() == Report.Status.RESOLVED) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_RESOLVED", "Rapor zaten sonuçlandırılmış.");
        }
        ReportTargetHandler h = handler(report.getTargetType());
        Optional<Long> owner = h.exists(report.getTargetId()) ? h.ownerId(report.getTargetId()) : Optional.empty();

        switch (action) {
            case DISMISS -> { }
            case HIDE -> h.hide(report.getTargetId());
            case WARN -> owner.ifPresent(uid -> notifications.sendLocalized(uid, NotificationType.SYSTEM,
                    "notif.report.warn.title", message == null || message.isBlank() ? "notif.report.warn.body" : null,
                    message, null));
            case SUSPEND_USER -> owner.ifPresent(uid -> userModeration.suspend(uid, message));
        }

        Instant now = Instant.now();
        for (Report r : reports.findByTargetTypeAndTargetIdAndStatus(report.getTargetType(), report.getTargetId(),
                Report.Status.OPEN)) {
            r.setStatus(Report.Status.RESOLVED);
            r.setResolution(action);
            r.setResolvedBy(adminId);
            r.setResolvedAt(now);
        }
    }

    private ReportTargetHandler handler(ReportTargetType type) {
        ReportTargetHandler h = handlers.get(type);
        if (h == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TARGET_TYPE_UNSUPPORTED", "Bu tür henüz raporlanamıyor.");
        }
        return h;
    }
}
