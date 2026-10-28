package edu.bingol.backend.mail.admin;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.mail.MailDailyQuota;
import edu.bingol.backend.mail.MailStatus;
import edu.bingol.backend.mail.admin.MailOpsDtos.QueueCounts;
import edu.bingol.backend.mail.admin.MailOpsDtos.QuotaDay;
import edu.bingol.backend.mail.admin.MailOpsDtos.QuotaView;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gunluk gonderim kotasi gorunumu (P13; salt okunur). Sayac Redis'te yalniz 2 gun yasar: gecmis olarak dun ve bugun
 * doner (7 gunluk tarihce tutulmaz). Yuzde &gt;= 80 WARN, &gt;= 95 CRITICAL.
 */
@Service
public class MailQuotaAdminService {

    public static final double WARN_PERCENT = 80;
    public static final double CRITICAL_PERCENT = 95;

    private final MailDailyQuota quota;
    private final MailProperties props;
    private final MailOutboxQueryRepository outbox;

    public MailQuotaAdminService(MailDailyQuota quota, MailProperties props, MailOutboxQueryRepository outbox) {
        this.quota = quota;
        this.props = props;
        this.outbox = outbox;
    }

    @Transactional(readOnly = true)
    public QuotaView view() {
        Instant now = Instant.now();
        boolean enabled = quota.enabled();
        int limit = quota.limit();
        long used = quota.used();
        int cap = quota.announcementCap();
        double percent = enabled ? Math.round(used * 1000.0 / limit) / 10.0 : -1;
        String level = !enabled ? "OFF" : percent >= CRITICAL_PERCENT ? "CRITICAL" : percent >= WARN_PERCENT ? "WARN" : "OK";
        Instant dayStart = quota.dayStart(now);
        List<QuotaDay> history = List.of(
                new QuotaDay(quota.dayStart(now.minus(Duration.ofDays(1))).toString(), quota.usedAt(now.minus(Duration.ofDays(1)))),
                new QuotaDay(dayStart.toString(), used));
        Instant oldest = outbox.oldestCreated(Set.of(MailStatus.PENDING, MailStatus.FAILED));
        QueueCounts queue = new QueueCounts(outbox.countByStatus(MailStatus.PENDING),
                outbox.countByStatus(MailStatus.FAILED), outbox.countByStatus(MailStatus.DEAD),
                outbox.countByStatus(MailStatus.SKIPPED), oldest == null ? null : oldest.toString());
        return new QuotaView(props.enabled(), enabled, limit, Math.max(0, props.dailyReserve()), cap, used,
                enabled ? Math.max(0, limit - used) : -1, enabled ? Math.max(0, cap - used) : -1, percent, level,
                Math.min(23, Math.max(0, props.dailyResetHourUtc())), dayStart.toString(),
                quota.nextReset(now).toString(), quota.publicUsed(),
                enabled ? quota.publicCap(MailDailyQuota.CodeKind.REGISTRATION) : -1,
                enabled ? quota.publicCap(MailDailyQuota.CodeKind.PASSWORD_RESET) : -1,
                quota.maxCodesPerEmailPerDay(), quota.maxCodeRequestsPerIpPerDay(), history,
                "Sayaç Redis'te 2 gün saklanır; daha eski gün gösterilmez.", queue);
    }
}
