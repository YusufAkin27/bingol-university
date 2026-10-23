package edu.bingol.backend.analytics;

import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignView;
import edu.bingol.backend.status.dto.SourceStatus;
import java.util.List;
import java.util.Map;

/** /api/admin/analytics/* yanit sekilleri (docs/ADMIN_API.md ile birebir). */
public final class ReportDtos {

    private ReportDtos() {}

    public record NewUsers(long today, long last7d, long last30d) {}

    public record ActiveUsers(long dau, long wau, long mau) {}

    public record MessageCounts(long total, long last24h) {}

    public record CommunityCounts(long active, long pending) {}

    public record EventCounts(long upcoming, long pending) {}

    public record DeviceCounts(long android, long ios, long web) {}

    public record Overview(long totalUsers, long verifiedUsers, long suspendedUsers, NewUsers newUsers,
                           ActiveUsers activeUsers, double stickiness, MessageCounts messages,
                           CommunityCounts communities, EventCounts events, long openReports, long openTickets,
                           long newFeedback, long pushCampaignsSent30d, long bookmarks, DeviceCounts devices) {}

    public record RegistrationPoint(String date, long count, long cumulative) {}

    public record Registrations(List<RegistrationPoint> points) {}

    public record DauPoint(String date, long dau) {}

    public record ActiveUsersReport(List<DauPoint> points, long wau, long mau) {}

    public record BreakdownItem(String key, String label, long count, double percent) {}

    public record Breakdown(String dimension, long total, List<BreakdownItem> items) {}

    public record TopEvent(String name, long count, long uniqueUsers) {}

    public record ScreenViews(String screen, long views) {}

    public record EngagementDay(String date, long messages, long posts, long rsvps, long searches) {}

    public record FunnelStep(String step, long count) {}

    public record Engagement(List<TopEvent> topEvents, List<ScreenViews> screens, List<EngagementDay> daily,
                             List<FunnelStep> funnel) {}

    public record Cohort(String weekStart, long size, double d1, double d7, double d30) {}

    public record Retention(List<Cohort> cohorts) {}

    public record TicketCounts(long open, long answered, long closed) {}

    public record KeyCount(String key, long count) {}

    public record SupportReport(TicketCounts tickets, double avgFirstResponseMinutes,
                                List<KeyCount> feedbackByCategory, List<KeyCount> feedbackByStatus) {}

    public record PushTotals(long campaigns, long recipients) {}

    public record PushReport(PushTotals totals, List<CampaignView> recent) {}

    public record ContentDay(String date, long news, long announcements, long events) {}

    public record ContentReport(List<ContentDay> daily, Map<String, SourceStatus> sources) {}
}
