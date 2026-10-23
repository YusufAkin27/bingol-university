package edu.bingol.backend.notification.dto;

import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationPref;
import edu.bingol.backend.notification.NotificationType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Bildirim modulunun istek/yanit tipleri. */
public final class NotificationDtos {

    private NotificationDtos() {}

    public record DeviceRequest(@NotBlank @Size(max = 500) String fcmToken,
                                @NotBlank @Pattern(regexp = "ANDROID|IOS|WEB") String platform) {}

    public record NotificationView(Long id, NotificationType type, String title, String body, String data,
                                   boolean read, String createdAt) {
        public static NotificationView of(Notification n) {
            return new NotificationView(n.getId(), n.getType(), n.getTitle(), n.getBody(), n.getData(),
                    n.getReadAt() != null, n.getCreatedAt().toString());
        }
    }

    public record NotificationPage(List<NotificationView> items, Long nextCursor, long unreadCount) {}

    /** ids veya all=true'dan biri verilmeli. */
    public record MarkReadRequest(List<Long> ids, Boolean all) {}

    public record PrefsView(boolean news, boolean announcements, boolean events, boolean messages,
                            boolean communities) {
        public static PrefsView of(NotificationPref p) {
            return new PrefsView(p.isNews(), p.isAnnouncements(), p.isEvents(), p.isMessages(), p.isCommunities());
        }
    }
}
