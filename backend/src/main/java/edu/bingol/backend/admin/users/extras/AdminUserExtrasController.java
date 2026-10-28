package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkRequest;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkResult;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.NotificationRow;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.ProfilePatch;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.ProfilePatchResult;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.PushDeviceInfo;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.SessionList;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * P09 yonetici kullanici derin yonetimi (/api/admin/** => ROLE_ADMIN): profil mudahalesi, refresh oturumlari, FCM
 * cihazlari, bildirim gecmisi, kullanici adina KVKK dis aktarma ve toplu islem. Sebep zorunlulugu ve hiz siniri
 * AdminGuardInterceptor/AdminGuardPolicy'dedir (yazma uclari otomatik kapsanir); denetim kaydini AuditInterceptor yazar.
 * Not: `GET /users/{id}/devices` erisim engeli modulunun cihaz GUNLUGUdur; FCM cihazlari `push-devices` altindadir.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminUserExtrasController {

    public static final String CONFIRM_HEADER = "X-Admin-Confirm";

    private final AdminUserProfileService profile;
    private final AdminUserSessionService sessions;
    private final AdminPushDeviceService devices;
    private final AdminUserNotificationService notifications;
    private final AdminUserExportService export;
    private final AdminUserBulkService bulk;

    public AdminUserExtrasController(AdminUserProfileService profile, AdminUserSessionService sessions,
                                     AdminPushDeviceService devices, AdminUserNotificationService notifications,
                                     AdminUserExportService export, AdminUserBulkService bulk) {
        this.profile = profile;
        this.sessions = sessions;
        this.devices = devices;
        this.notifications = notifications;
        this.export = export;
        this.bulk = bulk;
    }

    /** Avatar/biyografi temizleme ve gorunen ad duzeltme; sebep zorunlu, kullaniciya bildirim gider. */
    @PatchMapping("/users/{id}/profile")
    public ProfilePatchResult patchProfile(@PathVariable Long id, @RequestBody ProfilePatch body) {
        String reason = body.reason() != null && !body.reason().isBlank() ? body.reason() : AuditContext.currentReason();
        AuditContext.target("USER", id);
        ProfilePatchResult res = profile.patch(id, body, reason);
        AuditContext.summary("profil mudahalesi: avatar=" + res.avatarCleared() + " bio=" + res.bioCleared()
                + " ad=" + res.displayNameChanged());
        return res;
    }

    @GetMapping("/users/{id}/sessions")
    public SessionList sessions(@PathVariable Long id) {
        AuditContext.target("USER", id);
        return sessions.list(id);
    }

    @DeleteMapping("/users/{id}/sessions/{sessionId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revokeSession(@PathVariable Long id, @PathVariable String sessionId) {
        AuditContext.target("USER", id).summary("tek oturum sonlandirildi: " + sessionId);
        sessions.revoke(id, sessionId);
    }

    @GetMapping("/users/{id}/push-devices")
    public List<PushDeviceInfo> pushDevices(@PathVariable Long id) {
        AuditContext.target("USER", id);
        return devices.list(id);
    }

    @DeleteMapping("/users/{id}/push-devices/{deviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePushDevice(@PathVariable Long id, @PathVariable Long deviceId) {
        AuditContext.target("USER", id).summary("push cihaz kaydi silindi: " + deviceId);
        devices.delete(id, deviceId);
    }

    /** Bildirim kutusu gecmisi: icerik kisisel veri olabilir, okuma denetim kaydina yazilir. */
    @AuditRead
    @GetMapping("/users/{id}/notifications")
    public PageResponse<NotificationRow> notifications(@PathVariable Long id,
                                                       @RequestParam(required = false) String type,
                                                       @RequestParam(defaultValue = "false") boolean unread,
                                                       @RequestParam(defaultValue = "0") int page,
                                                       @RequestParam(defaultValue = "20") int size) {
        AuditContext.target("USER", id).summary("bildirim kutusu goruntulendi");
        return notifications.list(id, type, unread, page, size);
    }

    /**
     * Kullanici adina KVKK dis aktarma: sebep >= 20 karakter + `X-Admin-Confirm: <kullanici kimligi>`; kullanici basina
     * gunde bir. Yalniz yoneticiye indirilebilir yanit; kullaniciya bildirim GITMEZ.
     */
    @PostMapping("/users/{id}/export")
    public ResponseEntity<Map<String, Object>> exportUser(@PathVariable Long id,
                                                          @RequestHeader(value = CONFIRM_HEADER, required = false) String confirm) {
        AuditContext.target("USER", id).summary("kullanici adina KVKK dis aktarma");
        Map<String, Object> body = export.export(id, AuditContext.currentReason(), confirm);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"user-" + id + "-data.json\"")
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(body);
    }

    /** Toplu askiya al / geri ac / oturum kapat (<= 100 kimlik); kismi basari raporu doner. */
    @PostMapping("/users/bulk")
    public BulkResult bulk(@Valid @RequestBody BulkRequest r, Authentication auth) {
        String reason = r.reason() != null && !r.reason().isBlank() ? r.reason() : AuditContext.currentReason();
        AuditContext.target("USER", null);
        BulkResult res = bulk.run(actorId(auth), r.action(), r.ids(), reason);
        AuditContext.summary("toplu " + r.action() + ": istenen=" + res.requested() + " yapilan=" + res.done()
                + " atlanan=" + res.skipped() + " basarisiz=" + res.failed());
        return res;
    }

    private static Long actorId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }
}
