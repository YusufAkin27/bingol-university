package edu.bingol.backend.admin;

import edu.bingol.backend.analytics.ActivityRepository.DayOpens;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/** Yonetim paneli yanit/istek sekilleri (docs/ADMIN_API.md). */
public final class AdminDtos {

    private AdminDtos() {}

    /** Sayfali liste: page 0 tabanli. */
    public record PageResponse<T>(List<T> items, int page, int totalPages, long totalItems) {
        public static <T> PageResponse<T> of(List<T> items, int page, int size, long total) {
            return new PageResponse<>(items, page, (int) ((total + size - 1) / size), total);
        }
    }

    public record AdminMe(Long id, String email, String displayName, Role role) {}

    public record AdminUserRow(Long id, String email, String displayName, String faculty, String department,
                               Short classYear, String language, Role role, UserStatus status, boolean emailVerified,
                               String createdAt, String lastSeenAt, String avatarUrl) {}

    public record Counts(long feedback, long tickets, long reportsAgainst, long reportsFiled, long conversations,
                         long communities, long eventsCreated, long bookmarks) {}

    public record Consent(String type, int version, String acceptedAt) {}

    /** AdminUserRow alanlari + ayrintilar (alanlar duzdur; JSON'da ic ice degil). */
    public record AdminUserDetail(Long id, String email, String displayName, String faculty, String department,
                                  Short classYear, String language, Role role, UserStatus status,
                                  boolean emailVerified, String createdAt, String lastSeenAt, String avatarUrl,
                                  String bio, String suspendedReason, String deletedAt, long deviceCount,
                                  List<String> platforms, Counts counts, List<Consent> consents,
                                  List<DayOpens> recentActivity, Extras extras) {}

    // --- kullanici detayi icin ek ayrintilar (mesaj ICERIGI hicbir zaman dahil degildir; yalnizca sayilar) ---

    public record Device(String platform, String registeredAt) {}

    public record CommunityInfo(Long id, String name, String role, String status, String joinedAt) {}

    public record EventInfo(Long id, String title, String startsAt, String status, String rsvp) {}

    public record FeedbackInfo(Long id, String category, String subject, String status, String createdAt) {}

    public record TicketInfo(Long id, String category, String subject, String status, String createdAt) {}

    public record ReportInfo(Long id, String targetType, Long targetId, String reason, String status, String createdAt) {}

    public record NotificationPrefs(boolean news, boolean announcements, boolean events, boolean messages,
                                    boolean communities) {}

    /** Kullanici detayinin ek bolumleri. */
    public record Extras(boolean showEmail, NotificationPrefs notificationPrefs, long notificationsTotal,
                         long notificationsUnread, long messagesSent, long blocking, long blockedBy,
                         List<Device> devices, List<CommunityInfo> communities, List<EventInfo> eventsCreated,
                         List<EventInfo> eventsAttending, List<FeedbackInfo> feedback, List<TicketInfo> tickets,
                         List<ReportInfo> reportsAgainst, List<ReportInfo> reportsFiled) {}

    public record RoleRequest(@NotNull Role role) {}

    public record AuditRow(Long id, Long adminId, String adminEmail, String method, String path, int status,
                           String at, String ip) {}

    public record AdminNewsRow(Long id, String type, String title, String summary, String url, String imageUrl,
                               String publishedDate, String fetchedAt, boolean hidden) {}

    public record HiddenRequest(@NotNull Boolean hidden) {}

    public record LegalVersion(int version, String lang, String title, String content, boolean requireReaccept,
                               boolean active, String publishedAt) {}

    public record AcceptanceStat(String type, int version, long accepted, long totalActiveUsers) {}
}
