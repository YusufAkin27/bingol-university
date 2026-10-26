package edu.bingol.backend.notification;

import edu.bingol.backend.notification.dto.NotificationDtos.DeviceView;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/** Cihaz (FCM token) yonetimi: el degistirme, cok cihaz, kullanici basina sinir. */
@Service
public class DeviceService {

    /** Kullanici basina en fazla cihaz; asilirsa en eski guncellenenler silinir. */
    public static final int MAX_DEVICES = 10;

    private final DeviceRepository devices;

    public DeviceService(DeviceRepository devices) {
        this.devices = devices;
    }

    public void register(Long userId, String token, String platform) {
        register(userId, token, platform, null, null);
    }

    /**
     * Upsert: ayni token baska kullaniciya aitse yeni kullaniciya tasinir (hesap/cihaz degisimi); tekrar kayit
     * son gorulmeyi yeniler.
     */
    public void register(Long userId, String token, String platform, String appVersion, String locale) {
        Device d = devices.findByFcmToken(token).orElseGet(Device::new);
        Instant now = Instant.now();
        d.setFcmToken(token);
        d.setUserId(userId);
        d.setPlatform(platform.toUpperCase(Locale.ROOT));
        d.setAppVersion(appVersion);
        d.setLocale(locale);
        d.setUpdatedAt(now);
        d.setLastSeenAt(now);
        try {
            devices.saveAndFlush(d);
        } catch (DataIntegrityViolationException e) {
            // Es zamanli iki kayit: token benzersizligi; digeri kazandi, bu cagri yenileme sayilir.
            return;
        }
        List<Device> mine = devices.findByUserIdOrderByUpdatedAtDesc(userId);
        if (mine.size() > MAX_DEVICES) {
            devices.deleteAll(mine.subList(MAX_DEVICES, mine.size()));
        }
    }

    public List<DeviceView> list(Long userId) {
        return devices.findByUserIdOrderByUpdatedAtDesc(userId).stream().map(DeviceView::of).toList();
    }

    public void unregister(Long userId, String token) {
        devices.deleteByFcmTokenAndUserId(token, userId);
    }
}
