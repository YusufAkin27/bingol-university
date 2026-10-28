package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.users.extras.UserExtrasDtos.PushDeviceInfo;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici icin FCM cihaz kayitlari: liste (token maskeli) ve tek cihaz silme. */
@Service
public class AdminPushDeviceService {

    /** Token'in gosterilen son karakter sayisi; tamami ASLA donmez. */
    static final int TAIL = 6;

    private final DeviceRepository devices;
    private final UserRepository users;

    public AdminPushDeviceService(DeviceRepository devices, UserRepository users) {
        this.devices = devices;
        this.users = users;
    }

    public List<PushDeviceInfo> list(Long userId) {
        Targets.existing(users, userId);
        return devices.findByUserIdOrderByUpdatedAtDesc(userId).stream().map(AdminPushDeviceService::view).toList();
    }

    /** Cihaz kaydini siler (kullanici bir sonraki acilista yeniden kaydeder). Baska kullanicinin cihazi 404. */
    @Transactional
    public void delete(Long userId, Long deviceId) {
        Targets.existing(users, userId);
        Device d = devices.findById(deviceId).filter(x -> userId.equals(x.getUserId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PUSH_DEVICE_NOT_FOUND",
                        "Cihaz kaydı bulunamadı."));
        devices.delete(d);
    }

    /** Son {@value #TAIL} karakter; kisa token'da bile tamami acilmaz (en cok uzunlugun dortte biri). */
    static String tail(String token) {
        if (token == null || token.isEmpty()) {
            return "";
        }
        int n = Math.min(TAIL, Math.max(1, token.length() / 4));
        return token.substring(token.length() - n);
    }

    static PushDeviceInfo view(Device d) {
        return new PushDeviceInfo(d.getId(), d.getPlatform(), d.getAppVersion(), d.getLocale(), tail(d.getFcmToken()),
                d.getCreatedAt() == null ? null : d.getCreatedAt().toString(),
                d.getLastSeenAt() == null ? null : d.getLastSeenAt().toString());
    }
}
