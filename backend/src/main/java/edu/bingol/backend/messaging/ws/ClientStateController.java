package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Istemci durum sinyalleri (bildirim bastirma): hangi sohbet acik, uygulama on planda mi.
 * Hepsi TTL'li Redis anahtaridir; istemci yenilemezse kendiliginden duser (push yeniden acilir).
 */
@RestController
@RequestMapping("/api")
public class ClientStateController {

    /** @param foreground true: uygulama on planda (TTL 90 sn; istemci 45 sn'de bir yeniler); false: arka plana gecti */
    public record DeviceState(@NotNull Boolean foreground) {}

    private final PresenceService presence;
    private final ConversationMemberRepository members;
    private final RateLimiter limiter;
    private final edu.bingol.backend.notification.DeviceRepository devices;

    public ClientStateController(PresenceService presence, ConversationMemberRepository members, RateLimiter limiter,
                                 edu.bingol.backend.notification.DeviceRepository devices) {
        this.devices = devices;
        this.presence = presence;
        this.members = members;
        this.limiter = limiter;
    }

    /** Sohbet acildi / yenile (30 sn'de bir). Uye degilse 404 (varlik sizdirilmaz). */
    @PutMapping("/conversations/{id}/viewing")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void viewing(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("viewing:" + uid, 6, Duration.ofMinutes(1)); // 30 sn'de bir yenileme + sohbet gecisleri
        if (members.findByConversationIdAndUserIdAndLeftAtIsNull(id, uid).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        presence.setViewing(uid, id);
    }

    /** Sohbetten cikildi. Idempotent. */
    @DeleteMapping("/conversations/{id}/viewing")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void stopViewing(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("viewing:" + uid, 12, Duration.ofMinutes(1));
        presence.clearViewing(uid, id);
    }

    /** Uygulama on plana / arka plana gecti. */
    @PutMapping({"/devices/{fcmToken}/state", "/devices/state"})
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void state(@PathVariable(required = false) String fcmToken,
                      @RequestBody @jakarta.validation.Valid DeviceState s) {
        Long uid = CurrentUser.id();
        limiter.check("devstate:" + uid, 30, Duration.ofMinutes(1));
        if (fcmToken != null && devices.findByFcmToken(fcmToken).filter(d -> uid.equals(d.getUserId())).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND); // baskasinin/kayitsiz token
        }
        presence.setForeground(uid, s.foreground());
    }
}
