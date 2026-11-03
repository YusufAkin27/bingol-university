package edu.bingol.backend.analytics.behavior;

import java.time.Instant;
import java.util.List;

/**
 * Kullanici davranis analizi yanit sozlesmesi (docs/ADMIN_API.md "Kullanici davranis analizi"). Sureler milisaniye,
 * oranlar 0..1 (sharePct dahil), gunler Europe/Istanbul yyyy-MM-dd.
 */
public final class BehaviorDtos {

    private BehaviorDtos() {}

    public record DayStat(String day, int sessions, long avgSessionMs, double bounceRate) {}

    public record Bucket(String label, int sessions) {}

    public record Overview(int sessions, int users, long avgSessionMs, long medianSessionMs, double avgScreensPerSession,
                           double sessionsPerUser, double bounceRate, double quickCloseRate, List<DayStat> byDay,
                           List<Bucket> durationBuckets) {}

    public record ScreenStat(String screen, int views, int users, long avgDwellMs, long medianDwellMs, long p90DwellMs,
                             double exitRate, double bounceRate, double sharePct) {}

    public record ScreensPage(List<ScreenStat> items, int page, int size, long total) {}

    public record Transition(String from, String to, int count) {}

    public record ScreenSessions(String screen, int sessions) {}

    public record DropOff(String screen, int entered, int left, double leftRate) {}

    public record Flows(List<Transition> topTransitions, List<ScreenSessions> entryScreens,
                        List<ScreenSessions> exitScreens, List<DropOff> dropOff) {}

    public record ScreenCount(String screen, int count) {}

    public record ActionStat(String kind, int count, int users, List<ScreenCount> perScreen) {}

    public record Actions(List<ActionStat> items) {}

    public record TopScreen(String screen, long ms) {}

    public record UserRow(long userId, String displayName, String email, String department, String grade, int sessions,
                          long totalMs, long avgSessionMs, double bounceRate, int quickCloseCount, Instant lastSeenAt,
                          List<TopScreen> topScreens) {}

    public record UsersPage(List<UserRow> items, int page, int size, long total) {}

    public record UserInfo(long userId, String displayName, String email, String department, String grade) {}

    public record UserSummary(int sessions, long totalMs, long avgSessionMs, double bounceRate, int quickCloseCount,
                              Instant lastSeenAt) {}

    /** type=screen: dwellMs (yoksa null); type=action: kind. */
    public record StepOut(String type, String screen, String kind, Long dwellMs, Instant at) {}

    public record SessionOut(String sid, Instant startedAt, Instant endedAt, long durationMs, boolean bounce,
                             boolean quickClose, String reason, List<StepOut> steps) {}

    public record UserDetail(UserInfo user, UserSummary summary, List<SessionOut> sessions) {}
}
