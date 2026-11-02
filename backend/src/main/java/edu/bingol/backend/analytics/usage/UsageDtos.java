package edu.bingol.backend.analytics.usage;

import java.util.List;

/**
 * /api/admin/analytics/usage/* yanit sekilleri (docs/ADMIN_API.md ve docs/USAGE_STATS.md ile birebir). Hepsi
 * toplulastirilmis ve kimliksizdir; "userDays" = gunluk tekil kullanicilarin aralik boyunca toplami (tekil kisi degil).
 */
public final class UsageDtos {

    private UsageDtos() {
    }

    // --- ozet ---

    public record DayUsage(String date, long dau, long reportingUsers, long sessions, long screenViews) {}

    /** avgSessionSeconds: app_background `dur` ortalamasi (veri yoksa null). */
    public record Summary(String from, String to, long totalSessions, long totalScreenViews, double avgDau,
                          double avgReportingUsers, Double avgSessionSeconds, String topScreen, String topAction,
                          List<DayUsage> daily) {}

    // --- en cok gezilen ekranlar ---

    /**
     * avgSeconds/medianSeconds: bu ekranda gecirilen sure (veri yoksa null); exitPercent: ardindan baska ekrana
     * gecilmeyen goruntuleme yuzdesi; trend: `dates` ile ayni uzunlukta gunluk goruntuleme.
     */
    public record ScreenItem(String screen, long views, long userDays, double avgDailyUsers, Double avgSeconds,
                             Double medianSeconds, double exitPercent, List<Long> trend) {}

    public record TopScreens(String from, String to, List<String> dates, long totalViews, List<ScreenItem> items) {}

    // --- en cok yapilan eylemler ---

    /** adoptionPercent: eylemi yapan gunluk kullanici toplami / olay gonderen gunluk kullanici toplami. */
    public record ActionItem(String action, long count, long userDays, double adoptionPercent, List<Long> trend) {}

    public record TopActions(String from, String to, List<String> dates, long totalEvents, double avgReportingUsers,
                             List<ActionItem> items) {}

    // --- akis ---

    public record FlowEdge(String from, String to, long count) {}

    public record Flow(String from, String to, long totalTransitions, List<FlowEdge> edges) {}

    // --- saat x gun ---

    /** dow: ISO hafta gunu 1=Pazartesi .. 7=Pazar; hour: Istanbul saati 0-23. 168 hucre, bos olanlar 0. */
    public record HourCell(int dow, int hour, long sessions, long views) {}

    public record Peak(int dow, int hour, long sessions) {}

    public record Hourly(String from, String to, long totalSessions, long totalViews, Peak peak, List<HourCell> cells) {}

    // --- kirilimlar ---

    /** key: 'other' (k-anonimlik esiginin altinda birlesenler) ya da 'unknown' olabilir. */
    public record SegmentItem(String key, long userDays, double percent) {}

    public record Segments(String from, String to, int kAnonymity, List<SegmentItem> platforms,
                           List<SegmentItem> versions, List<SegmentItem> faculties, List<SegmentItem> departments) {}

    // --- ozellik benimseme ---

    public record FeatureItem(String feature, long users, double percentOfMau) {}

    /** asOf: son tamamlanmis gunluk goruntu (30 gunluk pencerenin son gunu); veri yoksa null ve items bos. */
    public record Features(String asOf, long mau, long reportingUsers, List<FeatureItem> items) {}
}
