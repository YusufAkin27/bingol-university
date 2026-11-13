package edu.bingol.backend.notification;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.dto.NotificationDtos.DeletedCount;
import edu.bingol.backend.notification.dto.NotificationDtos.DeviceRequest;
import edu.bingol.backend.notification.dto.NotificationDtos.DeviceView;
import edu.bingol.backend.notification.dto.NotificationDtos.MarkReadRequest;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsUpdate;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsView;
import edu.bingol.backend.notification.dto.NotificationDtos.UnreadCount;
import edu.bingol.backend.notification.dto.NotificationDtos.UnreadCounts;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
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

/** Cihaz kaydi, bildirim kutusu ve tercihler. */
@RestController
@RequestMapping("/api")
public class NotificationController {

    private static final Duration MINUTE = Duration.ofMinutes(1);

    private final NotificationInboxService inbox;
    private final NotificationPrefService prefs;
    private final DeviceService devices;
    private final RateLimiter limiter;

    public NotificationController(NotificationInboxService inbox, NotificationPrefService prefs, DeviceService devices,
                                  RateLimiter limiter) {
        this.inbox = inbox;
        this.prefs = prefs;
        this.devices = devices;
        this.limiter = limiter;
    }

    @PostMapping("/devices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void registerDevice(@Valid @RequestBody DeviceRequest r, jakarta.servlet.http.HttpServletRequest http) {
        Long uid = CurrentUser.id();
        // Uygulama her acilista/token yenilemede kaydolur: dar sinir (eski 30/sa) 429 ile kaydi dusurup kullaniciyi
        // push'suz birakabilirdi. Silme sayaci ayri tutulur.
        limiter.check("dev-reg:" + uid, 120, Duration.ofHours(1));
        Object sid = http == null ? null : http.getAttribute(edu.bingol.backend.auth.jwt.JwtAuthFilter.SESSION_ID_ATTR);
        devices.register(uid, r.fcmToken(), r.platform(), r.appVersion(), r.locale(),
                Boolean.TRUE.equals(r.richNotifications()), sid instanceof String s ? s : null);
    }

    @GetMapping("/devices")
    public List<DeviceView> myDevices() {
        return devices.list(CurrentUser.id());
    }

    /**
     * Cihaz kaydini siler. Yol degiskeni cihaz KIMLIGI (yalniz rakam, `GET /devices` yanitindaki `id`) ya da eski
     * istemciler icin FCM token'i olabilir. Token URL'de erisim gunluklerine duser; yeni istemciler kimlik kullanmali.
     */
    @DeleteMapping("/devices/{idOrToken}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregisterDevice(@PathVariable String idOrToken) {
        Long uid = CurrentUser.id();
        limiter.check("dev-unreg:" + uid, 60, Duration.ofHours(1));
        if (DeviceService.isDeviceId(idOrToken)) {
            devices.unregisterById(uid, Long.parseLong(idOrToken));
        } else {
            devices.unregister(uid, idOrToken);
        }
    }

    /** type=EVENT gibi tur filtresi ve unread=true (yalnizca okunmamislar) destekler. */
    @GetMapping("/notifications")
    public NotificationPage list(@RequestParam(required = false) Long cursor,
                                 @RequestParam(defaultValue = "20") int size,
                                 @RequestParam(required = false) String type,
                                 @RequestParam(defaultValue = "false") boolean unread,
                                 @RequestParam(required = false) String category,
                                 @RequestParam(required = false) String scope,
                                 @RequestParam(required = false) String kind) {
        Long uid = CurrentUser.id();
        limiter.check("notif-list:" + uid, 120, MINUTE); // T-060
        return inbox.list(uid, cursor, size, type, unread, category, scope, kind);
    }

    /** Backward-compatible Java entry point used by internal callers. */
    public NotificationPage list(Long cursor, int size, String type, boolean unread) {
        return list(cursor, size, type, unread, null, null, null);
    }

    /** Hafif sayac (rozet icin sik cagrilabilir). */
    @GetMapping("/notifications/unread-count")
    public UnreadCount unreadCount() {
        Long uid = CurrentUser.id();
        limiter.check("notif-count:" + uid, 120, MINUTE);
        return new UnreadCount(inbox.unreadCount(uid));
    }

    /** Iki merkezin bagimsiz sayaclari: {social, information, unreadCount, pendingFollowRequests, pendingMembershipRequests}. */
    @GetMapping("/notifications/unread-counts")
    public UnreadCounts unreadCounts() {
        Long uid = CurrentUser.id();
        limiter.check("notif-count:" + uid, 120, MINUTE);
        return inbox.unreadCounts(uid);
    }

    @PostMapping("/notifications/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@Valid @RequestBody MarkReadRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("notif-write:" + uid, 120, MINUTE);
        inbox.markRead(uid, r.ids(), Boolean.TRUE.equals(r.all()), r.scope());
    }

    @PostMapping("/notifications/{id}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markOneRead(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("notif-write:" + uid, 120, MINUTE);
        inbox.markOneRead(uid, id);
    }

    @DeleteMapping("/notifications/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOne(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("notif-write:" + uid, 120, MINUTE);
        inbox.delete(uid, id);
    }

    /** Hepsini sil; type ile tek tur, readOnly=true ile yalnizca okunmuslar. */
    @DeleteMapping("/notifications")
    public DeletedCount deleteAll(@RequestParam(required = false) String type,
                                  @RequestParam(defaultValue = "false") boolean readOnly) {
        Long uid = CurrentUser.id();
        limiter.check("notif-write:" + uid, 120, MINUTE);
        return new DeletedCount(inbox.deleteAll(uid, type, readOnly));
    }

    @GetMapping("/notifications/preferences")
    public PrefsView getPrefs() {
        return prefs.get(CurrentUser.id());
    }

    /** Kismi guncelleme: gonderilmeyen alanlar degismez (eski 5 bayrakli istemci aynen calisir). */
    @PutMapping("/notifications/preferences")
    public PrefsView putPrefs(@Valid @RequestBody PrefsUpdate r) {
        Long uid = CurrentUser.id();
        limiter.check("notif-prefs:" + uid, 30, MINUTE);
        return prefs.update(uid, r);
    }
}
