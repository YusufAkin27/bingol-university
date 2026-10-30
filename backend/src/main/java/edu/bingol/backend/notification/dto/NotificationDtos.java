package edu.bingol.backend.notification.dto;

import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationPref;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Bildirim modulunun istek/yanit tipleri. */
public final class NotificationDtos {

    private NotificationDtos() {}

    public record DeviceRequest(@NotBlank @Size(min = 16, max = 500) String fcmToken,
                                @NotBlank @Pattern(regexp = "(?i)ANDROID|IOS|WEB") String platform,
                                @Size(max = 32) String appVersion, @Size(max = 16) String locale) {}

    /** Token'in tamami donmez (yalnizca son 6 karakter); silmek icin id kullanilir. */
    public record DeviceView(Long id, String platform, String tokenSuffix, String registeredAt, String updatedAt,
                             String appVersion, String locale, String lastSeenAt) {
        public static DeviceView of(Device d) {
            String t = d.getFcmToken();
            return new DeviceView(d.getId(), d.getPlatform(), t.length() <= 6 ? t : t.substring(t.length() - 6),
                    d.getCreatedAt().toString(), d.getUpdatedAt().toString(), d.getAppVersion(), d.getLocale(),
                    d.getLastSeenAt().toString());
        }
    }

    /** subtype ve count (gruplanmis bildirimdeki adet) eklendi; mevcut alanlar aynen korunur. */
    public record NotificationView(Long id, NotificationType type, String title, String body, String data,
                                   boolean read, String createdAt, String subtype, int count, String groupKey) {
        public static NotificationView of(Notification n) {
            return new NotificationView(n.getId(), n.getType(), n.getTitle(), n.getBody(), n.getData(),
                    n.getReadAt() != null, n.getCreatedAt().toString(), n.getSubtype(), n.getGroupCount(), n.getCollapseKey());
        }
    }

    public record NotificationPage(List<NotificationView> items, Long nextCursor, long unreadCount) {}

    public record UnreadCount(long unreadCount) {}

    public record DeletedCount(int deleted) {}

    /** ids veya all=true'dan biri verilmeli. */
    public record MarkReadRequest(List<Long> ids, Boolean all) {}

    /** Sessiz saatler; start/end "HH:mm" (kullanicinin saat diliminde), start == end gecersiz. */
    public record QuietHoursView(boolean enabled, @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String start,
                                 @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String end,
                                 @Size(max = 48) String timezone) {
        public static QuietHoursView of(NotificationPref p) {
            return new QuietHoursView(p.isQuietEnabled(), fmt(p.getQuietStart()), fmt(p.getQuietEnd()), p.getTimezone());
        }

        public static String fmt(int minute) {
            return String.format("%02d:%02d", minute / 60, minute % 60);
        }

        public static int parse(String hhmm) {
            return Integer.parseInt(hhmm.substring(0, 2)) * 60 + Integer.parseInt(hhmm.substring(3, 5));
        }
    }

    /** Yanit: 5 ana bayrak (eski istemciler yalniz bunlari okur) + sessiz saatler + alt tur bayraklari. */
    public record PrefsView(boolean news, boolean announcements, boolean events, boolean messages,
                            boolean communities, QuietHoursView quietHours, Map<String, Boolean> subtypes,
                            boolean polls, boolean academicAnnouncements) {
        public static PrefsView of(NotificationPref p) {
            return of(p, Map.of());
        }

        /** overrides: yalnizca kapatilmis/acilmis kayitli alt turler; digerleri varsayilan (acik). */
        public static PrefsView of(NotificationPref p, Map<String, Boolean> overrides) {
            Map<String, Boolean> all = new LinkedHashMap<>();
            for (NotificationSubtype s : NotificationSubtype.values()) {
                all.put(s.name(), s.flagBacked() ? s.flag(p) : overrides.getOrDefault(s.name(), true));
            }
            return new PrefsView(p.isNews(), p.isAnnouncements(), p.isEvents(), p.isMessages(), p.isCommunities(),
                    QuietHoursView.of(p), all, p.isPolls(), p.isAcademicAnnouncements());
        }
    }

    /** Kismi guncelleme: null alan degismez (eski 5 bayrakli istemciler geriye uyumlu). */
    public record PrefsUpdate(Boolean news, Boolean announcements, Boolean events, Boolean messages,
                              Boolean communities, @Valid QuietHoursView quietHours, Map<String, Boolean> subtypes,
                              Boolean polls, Boolean academicAnnouncements) {
        /** Eski 7 alanli kurucu (polls / academicAnnouncements degismez). */
        public PrefsUpdate(Boolean news, Boolean announcements, Boolean events, Boolean messages,
                           Boolean communities, QuietHoursView quietHours, Map<String, Boolean> subtypes) {
            this(news, announcements, events, messages, communities, quietHours, subtypes, null, null);
        }
    }
}
