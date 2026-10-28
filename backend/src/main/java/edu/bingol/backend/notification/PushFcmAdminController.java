package edu.bingol.backend.notification;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.fcm.FcmCheck;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici: FCM yapilandirma durumu ve kuru calistirma dogrulamasi (/api/admin/** => ROLE_ADMIN). */
@RestController
@RequestMapping("/api/admin/push/fcm")
public class PushFcmAdminController {

    private final PushDispatcher dispatcher;
    private final RateLimiter limiter;

    public PushFcmAdminController(PushDispatcher dispatcher, RateLimiter limiter) {
        this.dispatcher = dispatcher;
        this.limiter = limiter;
    }

    /** Ag cagrisi yapmaz: kimlik yuklendi mi, proje kimligi. */
    @GetMapping("/status")
    public FcmCheck status() {
        return dispatcher.fcmCheck(false);
    }

    /** Firebase'e validateOnly istegi atar (hicbir cihaza bildirim gitmez); dakikada 5. */
    @PostMapping("/validate")
    public FcmCheck validate() {
        limiter.check("fcm:validate:" + key(), 5, Duration.ofMinutes(1));
        return dispatcher.fcmCheck(true);
    }

    private static String key() {
        try {
            return String.valueOf(CurrentUser.id());
        } catch (RuntimeException e) {
            return "basic";
        }
    }
}
