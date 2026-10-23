package edu.bingol.backend.notification;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.notification.dto.NotificationDtos.DeviceRequest;
import edu.bingol.backend.notification.dto.NotificationDtos.MarkReadRequest;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsView;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Cihaz kaydi, bildirim listesi ve tercihler. */
@RestController
@RequestMapping("/api")
public class NotificationController {

    private final NotificationRepository notifications;
    private final NotificationPrefRepository prefs;
    private final DeviceRepository devices;

    public NotificationController(NotificationRepository notifications, NotificationPrefRepository prefs,
                                  DeviceRepository devices) {
        this.notifications = notifications;
        this.prefs = prefs;
        this.devices = devices;
    }

    /** Ayni token baska kullaniciya aitse (cihaz el degistirdi) yeni kullaniciya tasinir. */
    @PostMapping("/devices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void registerDevice(@Valid @RequestBody DeviceRequest r) {
        Long uid = CurrentUser.id();
        Device d = devices.findByFcmToken(r.fcmToken()).orElseGet(Device::new);
        d.setFcmToken(r.fcmToken());
        d.setUserId(uid);
        d.setPlatform(r.platform());
        devices.save(d);
    }

    @DeleteMapping("/devices/{token}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregisterDevice(@PathVariable String token) {
        devices.deleteByFcmTokenAndUserId(token, CurrentUser.id());
    }

    @GetMapping("/notifications")
    public NotificationPage list(@RequestParam(required = false) Long cursor,
                                 @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        int s = CursorPage.clampSize(size);
        List<Notification> rows = notifications.page(uid, cursor, PageRequest.of(0, s + 1));
        CursorPage<NotificationView> page = CursorPage.of(rows, s, Notification::getId, NotificationView::of);
        return new NotificationPage(page.items(), page.nextCursor(), notifications.countByUserIdAndReadAtIsNull(uid));
    }

    @PostMapping("/notifications/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@RequestBody MarkReadRequest r) {
        Long uid = CurrentUser.id();
        if (Boolean.TRUE.equals(r.all())) {
            notifications.markAllRead(uid);
        } else if (r.ids() != null && !r.ids().isEmpty()) {
            notifications.markRead(uid, r.ids());
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "ids veya all gerekli.");
        }
    }

    @GetMapping("/notifications/preferences")
    public PrefsView getPrefs() {
        Long uid = CurrentUser.id();
        return PrefsView.of(prefs.findById(uid).orElseGet(() -> NotificationPref.defaults(uid)));
    }

    @PutMapping("/notifications/preferences")
    public PrefsView putPrefs(@RequestBody PrefsView r) {
        NotificationPref p = prefs.findById(CurrentUser.id()).orElseGet(() -> NotificationPref.defaults(CurrentUser.id()));
        p.setNews(r.news());
        p.setAnnouncements(r.announcements());
        p.setEvents(r.events());
        p.setMessages(r.messages());
        p.setCommunities(r.communities());
        return PrefsView.of(prefs.save(p));
    }
}
