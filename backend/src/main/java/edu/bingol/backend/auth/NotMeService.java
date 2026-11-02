package edu.bingol.backend.auth;

import edu.bingol.backend.admin.AuditRepository;
import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * "Bu ben degilim" (yeni cihaz bildirimi): tum oturumlari kapatir (refresh + access, WebSocket ve push kaydi dahil),
 * guvenilen 2FA cihazlarini siler ve olayi denetim kaydina yazar. Sifre DEGISMEZ: istemci kullaniciyi sifre sifirlamaya
 * yonlendirir (kod e-postasiyla). Denetim yazilamazsa islem yine tamamlanir (guvenlik eylemi geri alinmaz).
 */
@Service
public class NotMeService {

    private static final Logger log = LoggerFactory.getLogger(NotMeService.class);

    private final AuthService auth;
    private final AuditRepository audit;
    private final ClientIp clientIp;

    public NotMeService(AuthService auth, AuditRepository audit, ClientIp clientIp) {
        this.auth = auth;
        this.audit = audit;
        this.clientIp = clientIp;
    }

    public void notMe(Long userId, HttpServletRequest http) {
        auth.logoutAll(userId); // refresh iptali + pwchg isareti + guvenilen cihazlar + cihaz kayitlari
        try {
            // Aktor e-postasi denetim tablosuna KOPYALANMAZ (hesap silinince anonimlesemezdi): "user:<id>" ve hedef kimligi
            audit.insert(null, "user:" + userId, "POST", "/api/security/not-me", 200, clientIp.of(http),
                    new AuditRepository.Details("USER", String.valueOf(userId), null,
                            "bu-ben-degilim: tum oturumlar kapatildi, guvenilen cihazlar silindi", null));
        } catch (RuntimeException e) {
            log.warn("Bu ben degilim denetim kaydi yazilamadi (user {}): {}", userId, e.toString());
        }
    }
}
