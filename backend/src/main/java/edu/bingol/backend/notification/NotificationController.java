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
    public void registerDevice(@Valid @RequestBody DeviceRequest r) {
        Long uid = CurrentUser.id();
        // Uygulama her acilista/token yenilemede kaydolur: dar sinir (eski 30/sa) 429 ile kaydi dusurup kullaniciyi
        // push'suz birakabilirdi. Silme sayaci ayri tutulur.
        limiter.check("dev-reg:" + uid, 120, Duration.ofHours(1));
        devices.register(uid, r.fcmToken(), r.platform(), r.appVersion(), r.locale());
    }

    @GetMapping("/devices")
    public List<DeviceView> myDevices() {
        return devices.list(CurrentUser.id());
    }

    @DeleteMapping("/devices/{token}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregisterDevice(@PathVariable String token) {
        Long uid = CurrentUser.id();
        limiter.check("dev-unreg:" + uid, 60, Duration.ofHours(1));
        devices.unregister(uid, token);
    }

    /** type=EVENT gibi tur filtresi ve unread=true (yalnizca okunmamislar) destekler. */
    @GetMapping("/notifications")
    public NotificationPage list(@RequestParam(required = false) Long cursor,
                                 @RequestParam(defaultValue = "20") int size,
                                 @RequestParam(required = false) String type,
                                 @RequestParam(defaultValue = "false") boolean unread) {
        Long uid = CurrentUser.id();
        limiter.check("notif-list:" + uid, 120, MINUTE); // T-060
        return inbox.list(uid, cursor, size, type, unread);
    }

    /** Hafif sayac (rozet icin sik cagrilabilir). */
    @GetMapping("/notifications/unread-count")
    public UnreadCount unreadCount() {
        Long uid = CurrentUser.id();
        limiter.check("notif-count:" + uid, 120, MINUTE);
        return new UnreadCount(inbox.unreadCount(uid));
    }

    @PostMapping("/notifications/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@RequestBody MarkReadRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("notif-write:" + uid, 120, MINUTE);
        inbox.markRead(uid, r.ids(), Boolean.TRUE.equals(r.all()));
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
