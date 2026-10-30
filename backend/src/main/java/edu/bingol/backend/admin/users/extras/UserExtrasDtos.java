package edu.bingol.backend.admin.users.extras;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/** P09 kullanici derin yonetimi: istek/yanit kayitlari (entity'ler API'ye donmez). */
public final class UserExtrasDtos {

    private UserExtrasDtos() {}

    /** Profil mudahalesi: en az bir alan dolu olmali; sebep basliktan (`X-Admin-Reason`) ya da buradan gelir. */
    public record ProfilePatch(Boolean clearAvatar, Boolean clearBio, String displayName, String reason) {}

    /** Hangi alanlarin GERCEKTEN degistigi (zaten bos olan alan degismis sayilmaz; hicbiri degismediyse bildirim gitmez). */
    public record ProfilePatchResult(boolean avatarCleared, boolean bioCleared, boolean displayNameChanged) {
        public boolean changed() {
            return avatarCleared || bioCleared || displayNameChanged;
        }
    }

    /**
     * Refresh oturumu ozeti. `id` oturum ozetinin ilk 16 hex'idir (opak; token'a donusturulemez). Redis'te yalniz
     * istemci turu + giris ani + sure tutulur: cihaz/IP bilgisi YOKTUR (kayit edilmez).
     */
    public record SessionInfo(String id, String client, String createdAt, String expiresAt) {}

    public record SessionList(int total, List<SessionInfo> items) {}

    /** FCM cihazi: token ASLA tam donmez, yalniz son 6 karakter. */
    public record PushDeviceInfo(Long id, String platform, String appVersion, String locale, String tokenTail,
                                 String createdAt, String lastSeenAt, String lastPushStatus, String lastPushErrorCode,
                                 String lastPushAt) {
        /** Eski 7 alanli kurucu (son push sonucu yok). */
        public PushDeviceInfo(Long id, String platform, String appVersion, String locale, String tokenTail,
                              String createdAt, String lastSeenAt) {
            this(id, platform, appVersion, locale, tokenTail, createdAt, lastSeenAt, null, null, null);
        }
    }

    public record NotificationRow(Long id, String type, String subtype, String title, String body, boolean read,
                                  int groupCount, String createdAt, String readAt) {}

    public enum BulkAction { SUSPEND, UNSUSPEND, REVOKE_SESSIONS }

    public record BulkRequest(@NotNull BulkAction action, @NotNull @NotEmpty List<Long> ids, String reason) {}

    public enum BulkStatus { DONE, SKIPPED, FAILED }

    /** `code`: DONE iken null; aksi halde makine kodu (ADMIN_TARGET, ADMIN_EMAIL_PINNED, SELF, ALREADY_SUSPENDED...). */
    public record BulkItemResult(Long id, BulkStatus status, String code) {}

    public record BulkResult(BulkAction action, int requested, int done, int skipped, int failed,
                             List<BulkItemResult> results) {}
}
