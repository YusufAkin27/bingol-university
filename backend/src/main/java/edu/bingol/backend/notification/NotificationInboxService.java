package edu.bingol.backend.notification;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Uygulama ici bildirim kutusu: liste, okundu, silme. Baskasinin bildirimi icin 404 doner (varligi sizmaz). */
@Service
public class NotificationInboxService {

    private static final List<NotificationType> ALL_TYPES = Arrays.asList(NotificationType.values());

    private final NotificationRepository notifications;

    public NotificationInboxService(NotificationRepository notifications) {
        this.notifications = notifications;
    }

    public NotificationPage list(Long userId, Long cursor, int size, String type, boolean unreadOnly) {
        int s = CursorPage.clampSize(size);
        List<Notification> rows = notifications.pageFiltered(userId, cursor, types(type), unreadOnly,
                PageRequest.of(0, s + 1));
        CursorPage<NotificationView> page = CursorPage.of(rows, s, Notification::getId, NotificationView::of);
        return new NotificationPage(page.items(), page.nextCursor(), notifications.countByUserIdAndReadAtIsNull(userId));
    }

    public long unreadCount(Long userId) {
        return notifications.countByUserIdAndReadAtIsNull(userId);
    }

    public void markRead(Long userId, List<Long> ids, boolean all) {
        if (all) {
            notifications.markAllRead(userId);
        } else if (ids != null && !ids.isEmpty()) {
            notifications.markRead(userId, ids);
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "ids veya all gerekli.");
        }
    }

    public void markOneRead(Long userId, Long id) {
        requireOwned(userId, id);
        notifications.markRead(userId, List.of(id));
    }

    public void delete(Long userId, Long id) {
        if (notifications.deleteOne(userId, id) == 0) {
            throw notFound();
        }
    }

    /** type verilirse yalnizca o tur; readOnly=true ise yalnizca okunmuslar. */
    public int deleteAll(Long userId, String type, boolean readOnly) {
        return notifications.deleteForUser(userId, types(type), readOnly);
    }

    private void requireOwned(Long userId, Long id) {
        notifications.findByIdAndUserId(id, userId).orElseThrow(NotificationInboxService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOTIFICATION_NOT_FOUND", "Bildirim bulunamadı.");
    }

    private static List<NotificationType> types(String type) {
        if (type == null || type.isBlank()) {
            return ALL_TYPES;
        }
        try {
            return List.of(NotificationType.valueOf(type.trim().toUpperCase(java.util.Locale.ROOT)));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim türü.");
        }
    }
}
