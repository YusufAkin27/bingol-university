package edu.bingol.backend.notification.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.admin.PushAdminDtos.CampaignFailures;
import edu.bingol.backend.notification.admin.PushAdminDtos.DayStat;
import edu.bingol.backend.notification.admin.PushAdminDtos.DeviceSummary;
import edu.bingol.backend.notification.admin.PushAdminDtos.FailureGroup;
import edu.bingol.backend.notification.admin.PushAdminDtos.NotificationStats;
import edu.bingol.backend.notification.admin.PushAdminDtos.TypeCount;
import edu.bingol.backend.notification.admin.PushAdminDtos.VersionCount;
import edu.bingol.backend.notification.campaign.PushCampaignRepository;
import edu.bingol.backend.notification.outbox.PushOutboxStatus;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici push altyapisi okuma yuzu: cihaz ozeti (yalniz toplu sayilar), kampanya hata gruplari ve global bildirim kutusu
 * istatistikleri. Kisisel veri (token, kullanici kimligi, mesaj icerigi) dondurulmez. Sorgular JPQL'dir (H2'de de calisir).
 */
@Service
public class PushOpsReadService {

    static final int MAX_FAILURE_GROUPS = 200;
    static final int DEFAULT_DAYS = 14;
    static final int MAX_DAYS = 30;
    private static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");
    private static final Set<String> PLATFORMS = Set.of("android", "ios", "web");

    @PersistenceContext
    private EntityManager em;

    private final PushCampaignRepository campaigns;

    public PushOpsReadService(PushCampaignRepository campaigns) {
        this.campaigns = campaigns;
    }

    @Transactional(readOnly = true)
    public DeviceSummary deviceSummary() {
        Instant now = Instant.now();
        long total = count("SELECT COUNT(d) FROM Device d");
        long users = count("SELECT COUNT(DISTINCT d.userId) FROM Device d");

        Map<String, Long> byPlatform = new LinkedHashMap<>();
        for (String p : List.of("android", "ios", "web", "other")) {
            byPlatform.put(p, 0L);
        }
        for (Object[] r : em.createQuery("SELECT LOWER(d.platform), COUNT(d) FROM Device d GROUP BY LOWER(d.platform)",
                Object[].class).getResultList()) {
            String key = r[0] == null ? "other" : String.valueOf(r[0]).toLowerCase(Locale.ROOT);
            if (!PLATFORMS.contains(key)) {
                key = "other";
            }
            byPlatform.merge(key, (Long) r[1], Long::sum);
        }

        List<VersionCount> versions = new ArrayList<>();
        for (Object[] r : em.createQuery("SELECT d.appVersion, COUNT(d) FROM Device d GROUP BY d.appVersion "
                + "ORDER BY COUNT(d) DESC, d.appVersion", Object[].class).setMaxResults(10).getResultList()) {
            versions.add(new VersionCount(r[0] == null ? "unknown" : (String) r[0], (Long) r[1]));
        }

        long active7 = em.createQuery("SELECT COUNT(d) FROM Device d WHERE d.lastSeenAt >= :t", Long.class)
                .setParameter("t", now.minus(Duration.ofDays(7))).getSingleResult();
        long stale30 = em.createQuery("SELECT COUNT(d) FROM Device d WHERE d.lastSeenAt < :t", Long.class)
                .setParameter("t", now.minus(Duration.ofDays(30))).getSingleResult();
        return new DeviceSummary(total, users, byPlatform, versions, active7, stale30);
    }

    /**
     * Kampanyanin kuyruk kayitlari: durum toplamlari + DEAD/FAILED kayitlarin hata koduna gore gruplari. Alici kimligi
     * dondurulmez (toplu sayilar). Surum oncesi kampanyalarin kayitlari baglanmadigindan linked=false doner.
     */
    @Transactional(readOnly = true)
    public CampaignFailures campaignFailures(Long campaignId) {
        if (!campaigns.existsById(campaignId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "CAMPAIGN_NOT_FOUND", "Kampanya bulunamadı.");
        }
        Map<String, Long> totals = new LinkedHashMap<>();
        for (PushOutboxStatus s : PushOutboxStatus.values()) {
            totals.put(s.name(), 0L);
        }
        long all = 0;
        for (Object[] r : em.createQuery("SELECT o.status, COUNT(o) FROM PushOutbox o WHERE o.campaignId = :c "
                + "GROUP BY o.status", Object[].class).setParameter("c", campaignId).getResultList()) {
            totals.put(((PushOutboxStatus) r[0]).name(), (Long) r[1]);
            all += (Long) r[1];
        }
        List<Object[]> rows = em.createQuery("SELECT o.status, o.errorCode, COUNT(o), MAX(o.createdAt) FROM PushOutbox o "
                        + "WHERE o.campaignId = :c AND o.status IN :st GROUP BY o.status, o.errorCode "
                        + "ORDER BY COUNT(o) DESC", Object[].class)
                .setParameter("c", campaignId)
                .setParameter("st", List.of(PushOutboxStatus.DEAD, PushOutboxStatus.FAILED))
                .setMaxResults(MAX_FAILURE_GROUPS + 1).getResultList();
        boolean truncated = rows.size() > MAX_FAILURE_GROUPS;
        List<FailureGroup> groups = new ArrayList<>();
        for (Object[] r : rows.subList(0, Math.min(rows.size(), MAX_FAILURE_GROUPS))) {
            groups.add(new FailureGroup(r[1] == null ? "UNKNOWN" : (String) r[1], ((PushOutboxStatus) r[0]).name(),
                    (Long) r[2], r[3] == null ? null : r[3].toString()));
        }
        return new CampaignFailures(campaignId, all > 0, totals, groups, truncated);
    }

    /** Son N gun (Istanbul gunleri, bugun dahil): olusturulan/okunan bildirim sayisi, tur dagilimi. */
    @Transactional(readOnly = true)
    public NotificationStats notificationStats(Integer daysParam) {
        int days = daysParam == null ? DEFAULT_DAYS : Math.min(MAX_DAYS, Math.max(1, daysParam));
        LocalDate today = LocalDate.now(ISTANBUL);
        List<DayStat> series = new ArrayList<>();
        long created = 0;
        long read = 0;
        for (int i = days - 1; i >= 0; i--) {
            LocalDate d = today.minusDays(i);
            Object[] r = em.createQuery("SELECT COUNT(n), COALESCE(SUM(CASE WHEN n.readAt IS NOT NULL THEN 1 ELSE 0 END), 0) "
                            + "FROM Notification n WHERE n.createdAt >= :s AND n.createdAt < :e", Object[].class)
                    .setParameter("s", d.atStartOfDay(ISTANBUL).toInstant())
                    .setParameter("e", d.plusDays(1).atStartOfDay(ISTANBUL).toInstant())
                    .getSingleResult();
            long c = ((Number) r[0]).longValue();
            long rd = ((Number) r[1]).longValue();
            series.add(new DayStat(d.toString(), c, rd));
            created += c;
            read += rd;
        }
        Instant from = today.minusDays(days - 1L).atStartOfDay(ISTANBUL).toInstant();
        List<TypeCount> byType = new ArrayList<>();
        for (Object[] r : em.createQuery("SELECT n.type, COUNT(n) FROM Notification n WHERE n.createdAt >= :f "
                + "GROUP BY n.type ORDER BY COUNT(n) DESC", Object[].class).setParameter("f", from).getResultList()) {
            byType.add(new TypeCount(String.valueOf(r[0]), (Long) r[1]));
        }
        long totalRows = count("SELECT COUNT(n) FROM Notification n");
        long unread = count("SELECT COUNT(n) FROM Notification n WHERE n.readAt IS NULL");
        return new NotificationStats(days, series, created == 0 ? null : (double) read / created, created, read, byType,
                totalRows, unread);
    }

    private long count(String jpql) {
        return em.createQuery(jpql, Long.class).getSingleResult();
    }
}
