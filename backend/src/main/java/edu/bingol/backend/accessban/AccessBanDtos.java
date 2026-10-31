package edu.bingol.backend.accessban;

import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/** Yonetici erisim engeli API'sinin istek/yanit kayitlari (sozlesme: docs/ADMIN_API.md). */
public final class AccessBanDtos {

    private AccessBanDtos() {}

    /** kind: IP | CIDR | DEVICE | USER. DEVICE icin value ham kimlik (8-128 kr, sunucu HMAC'ler, saklamaz) ya da 64 haneli ozet. */
    public record CreateBanRequest(String kind, String value, String reasonCode, String note, Instant expiresAt,
                                   Boolean alsoBlockUserDevices, Boolean alsoBlockUserIps, Boolean force) {}

    /** noExpiry=true suresiz yapar; expiresAt verilirse yeni bitis (gelecekte olmali). */
    public record PatchBanRequest(String note, Instant expiresAt, Boolean noExpiry, Boolean active) {}

    /** text: satir satir "IP-veya-CIDR [etiket]"; # ile baslayan ve bos satirlar atlanir. */
    public record BulkRequest(String text, String reasonCode, String note, Instant expiresAt, Boolean force) {}

    public record AnonymizerUpload(String text, String source) {}

    public record BlockAccessRequest(Boolean devices, Boolean ips, Boolean userBan, String reasonCode, String note,
                                     Instant expiresAt, Boolean force) {}

    public record BanView(Long id, String kind, String value, String valueShort, String note, String reasonCode,
                          Long createdBy, String createdAt, String expiresAt, boolean active, boolean effective,
                          long hitCount, String lastHitAt, Long userId, String userDisplayName) {
        /** T-018: IP/CIDR/cihaz degeri users.pii olmayan profile (VIEWER) maskeli; kullanici engeli (USER) kimlik tasir. */
        public BanView {
            if (!"USER".equals(kind)) {
                value = PermissionAwareMasking.opaque(value);
                valueShort = PermissionAwareMasking.opaque(valueShort);
            }
        }
    }

    public record RejectedLine(int line, String value, String error) {}

    public record BulkResult(int created, int alreadyBanned, int closedSessions, List<RejectedLine> rejected) {}

    public record AnonymizerView(Long id, String cidr, String source, String addedAt) {}

    public record AnonymizerList(boolean enforced, long total, Map<String, Long> bySource, List<AnonymizerView> items,
                                 Long nextCursor) {}

    public record AnonymizerUploadResult(int added, int duplicates, List<RejectedLine> rejected) {}

    public record BlockAccessResult(List<BanView> bans, int devicesBlocked, int ipsBlocked, int sessionsClosedUsers,
                                    List<String> warnings) {}

    public record AttemptView(Long id, String kind, String ip, String deviceShort, Long userId, String path, String at) {
        public AttemptView {
            ip = PermissionAwareMasking.opaque(ip);
            deviceShort = PermissionAwareMasking.opaque(deviceShort);
        }
    }

    public record IpSeen(String ip, int family, String firstSeenAt, String lastSeenAt, int seenCount, boolean blocked) {
        public IpSeen {
            ip = PermissionAwareMasking.opaque(ip);
        }
    }

    public record SharedUser(Long id, String displayName) {}

    public record DeviceView(String deviceHash, String deviceShort, String platform, String appVersion,
                             String firstSeenAt, String lastSeenAt, String lastEvent, int seenCount, String firstIp,
                             String lastIp, List<IpSeen> ips, boolean blocked, Long banId,
                             List<SharedUser> sharedWithUsers) {
        public DeviceView {
            deviceHash = PermissionAwareMasking.opaque(deviceHash);
            deviceShort = PermissionAwareMasking.opaque(deviceShort);
            firstIp = PermissionAwareMasking.opaque(firstIp);
            lastIp = PermissionAwareMasking.opaque(lastIp);
        }
    }

    public record UserDevices(Long userId, List<DeviceView> devices, List<IpSeen> unidentifiedIps) {}

    public record TopBan(Long id, String kind, String value, String note, long hitCount, String lastHitAt) {
        public TopBan {
            if (!"USER".equals(kind)) {
                value = PermissionAwareMasking.opaque(value);
            }
        }
    }

    public record Stats(Map<String, Long> activeBans, long anonymizerRanges, boolean anonymizersEnforced,
                        long blockedAttemptsLast24h, List<TopBan> topBans) {}
}
