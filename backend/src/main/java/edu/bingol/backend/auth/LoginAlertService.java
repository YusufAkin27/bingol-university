package edu.bingol.backend.auth;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import java.time.Clock;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Hesap guvenligi push + kutu bildirimleri (Stitch tasarimi 07): yeni cihazdan giris, oturumun baska cihazda acilmasi,
 * sifre degisimi. Tercih ve sessiz saatle KAPATILAMAZ (SYSTEM). Govde KVKK geregi e-posta/IP/sehir icermez; yalniz cihaz
 * adi (istemcinin gonderdigi model, yoksa platform) ve saat vardir.
 * <p>
 * Tek cihaz kurali (yeni mobil giris eski mobil oturumu kapatir ve eski cihazin FCM kaydini siler) yuzunden bildirim,
 * oturum iptalinden ONCE yakalanan cihaz token'lariyla gonderilir ({@link #snapshotDevices}); aksi halde hesabin asil
 * sahibinin (artik oturumu kapali) telefonu uyarilamazdi. Hicbir hata giris/sifre akisini bozmaz.
 */
@Component
public class LoginAlertService {

    private static final Logger log = LoggerFactory.getLogger(LoginAlertService.class);
    private static final DateTimeFormatter HOUR = DateTimeFormatter.ofPattern("HH:mm");
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private final NotificationService notifications;
    private final DeviceRepository devices;
    private final I18n i18n;
    private final Clock clock;

    public LoginAlertService(NotificationService notifications, DeviceRepository devices, I18n i18n, Clock clock) {
        this.notifications = notifications;
        this.devices = devices;
        this.i18n = i18n;
        this.clock = clock;
    }

    /** Kullanicinin o anki push cihazlari (oturum iptali/cihaz temizligi ONCESI cagrilmali). Hata durumunda bos. */
    public List<Device> snapshotDevices(Long userId) {
        try {
            return List.copyOf(devices.findByUserId(userId));
        } catch (RuntimeException e) {
            log.warn("Cihaz token'lari okunamadi (user {}): {}", userId, e.toString());
            return List.of();
        }
    }

    /**
     * Basarili girisin ardindan. `newDevice`: bu cihaz kullanicinin gecmisinde yok; `hadSessions`: baska bir mobil oturum
     * kapatildi (tek cihaz kurali); `oldDevices`: iptalden once yakalanan cihazlar. Yeni cihaz uyarisi (not_me) varsa
     * "oturum baska cihazda acildi" ayrica gonderilmez (ayni olay, tek bildirim).
     */
    public void afterLogin(User user, ClientContext ctx, boolean mobile, boolean newDevice, boolean hadSessions,
                           List<Device> oldDevices) {
        if (user == null || user.getId() == null || !(newDevice || hadSessions)) {
            return;
        }
        try {
            Lang lang = Lang.of(user.getLanguage());
            String device = deviceLabel(ctx);
            String time = HOUR.format(clock.instant().atZone(ZONE));
            // Mobil giriste eski cihazin token'lari (artik silinecek) hedeftir; web girisinde mevcut cihazlar
            List<Device> tokens = mobile ? oldDevices : null;
            if (newDevice) {
                notifications.sendSecurity(user.getId(),
                        i18n.msg("notif.security.newdevice.title", lang),
                        i18n.msg("notif.security.newdevice.body", lang, device, time), card("SECURITY_NEW_DEVICE"), tokens);
            } else {
                notifications.sendSecurity(user.getId(),
                        i18n.msg("notif.security.session.title", lang),
                        i18n.msg("notif.security.session.body", lang, device), card("SECURITY_SESSION"), tokens);
            }
        } catch (RuntimeException e) {
            log.warn("Giris guvenlik bildirimi gonderilemedi (user {}): {}", user.getId(), e.toString());
        }
    }

    /** Sifre degisti/sifirlandi: iptalden once yakalanan cihazlara (tumu, dogrudan) ve kutuya. */
    public void passwordChanged(User user, List<Device> tokens) {
        if (user == null || user.getId() == null) {
            return;
        }
        try {
            Lang lang = Lang.of(user.getLanguage());
            notifications.sendSecurity(user.getId(),
                    i18n.msg("notif.security.password.title", lang), i18n.msg("notif.security.password.body", lang),
                    card("SECURITY_PASSWORD"), tokens);
        } catch (RuntimeException e) {
            log.warn("Sifre degisti bildirimi gonderilemedi (user {}): {}", user.getId(), e.toString());
        }
    }

    /** Cihaz adi: istemcinin modeli, yoksa platform (Android/iOS/Web), yoksa bos metin yerine genel ad. */
    static String deviceLabel(ClientContext ctx) {
        if (ctx == null) {
            return "?";
        }
        if (ctx.deviceModel() != null && !ctx.deviceModel().isBlank()) {
            return ctx.deviceModel();
        }
        return switch (ctx.platform() == null ? "" : ctx.platform()) {
            case "ANDROID" -> "Android";
            case "IOS" -> "iOS";
            case "WEB" -> "Web";
            default -> "?";
        };
    }

    private static Map<String, String> card(String name) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("card", name);
        d.put("target", "SECURITY");
        d.put("value", name);
        return d;
    }
}
