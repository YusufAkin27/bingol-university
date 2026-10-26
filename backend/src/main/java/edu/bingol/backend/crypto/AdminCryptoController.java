package edu.bingol.backend.crypto;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.crypto.ConversationKeyService.RewrapResult;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeSet;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici sifreleme uclari (`/api/admin/**` yalnizca ADMIN; SecurityConfig). Yonetici kimligi JWT'den gelir. */
@RestController
@RequestMapping("/api/admin")
public class AdminCryptoController {

    public record RewrapRequest(String targetKeyId) {}

    private final AdminDecryptService decryptService;
    private final ConversationKeyService keyService;
    private final KeyProvider keyProvider;
    private final CryptoProperties props;
    private final RateLimiter limiter;

    public AdminCryptoController(AdminDecryptService decryptService, ConversationKeyService keyService,
                                 KeyProvider keyProvider, CryptoProperties props, RateLimiter limiter) {
        this.decryptService = decryptService;
        this.keyService = keyService;
        this.keyProvider = keyProvider;
        this.props = props;
        this.limiter = limiter;
    }

    /** POST /api/admin/messages/decrypt  {conversationId, fromMessageId, toMessageId?, reason} */
    @PostMapping("/messages/decrypt")
    public AdminDecryptService.Response decrypt(@RequestBody AdminDecryptService.Request req, HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limiter.check("admindecrypt:" + adminId, Math.max(1, props.adminDecryptPerHour()), Duration.ofHours(1));
        return decryptService.decrypt(adminId, req, http.getRemoteAddr());
    }

    /** GET /api/admin/crypto/status: anahtar kimlikleri ve hangi ana anahtarla kac DEK sarili (gizli veri yok). */
    @GetMapping("/crypto/status")
    public Map<String, Object> status() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("activeKeyId", keyProvider.activeKeyId());
        m.put("keyIds", new TreeSet<>(keyProvider.keyIds()));
        m.put("devKey", keyProvider.isDevKey());
        m.put("adminDecryptEnabled", props.adminDecryptEnabled());
        m.put("dekCountsByMasterKey", keyService.countsByMasterKey());
        return m;
    }

    /** POST /api/admin/crypto/rewrap {targetKeyId}: tum DEK'leri hedef ana anahtarla yeniden sarar. */
    @PostMapping("/crypto/rewrap")
    public RewrapResult rewrap(@RequestBody RewrapRequest req) {
        long adminId = CurrentUser.id();
        limiter.check("cryptorewrap:" + adminId, 10, Duration.ofHours(1));
        String target = req.targetKeyId() == null || req.targetKeyId().isBlank()
                ? keyProvider.activeKeyId() : req.targetKeyId();
        if (!keyProvider.keyIds().contains(target)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CRYPTO_KEY_UNKNOWN", "Bilinmeyen ana anahtar kimliği.");
        }
        return keyService.rewrapAll(target);
    }
}
