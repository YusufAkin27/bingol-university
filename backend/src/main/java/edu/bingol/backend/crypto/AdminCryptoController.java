package edu.bingol.backend.crypto;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.crypto.ConversationKeyService.RewrapResult;
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

/** Yonetici sifreleme uclari (mesaj goruntuleme: admin.chat.AdminChatViewerController) (`/api/admin/**` yalnizca ADMIN; SecurityConfig). Yonetici kimligi JWT'den gelir. */
@RestController
@RequestMapping("/api/admin")
public class AdminCryptoController {

    public record RewrapRequest(String targetKeyId) {}

    private final ConversationKeyService keyService;
    private final KeyProvider keyProvider;
    private final CryptoProperties props;
    private final RateLimiter limiter;

    public AdminCryptoController(ConversationKeyService keyService,
                                 KeyProvider keyProvider, CryptoProperties props, RateLimiter limiter) {
        this.keyService = keyService;
        this.keyProvider = keyProvider;
        this.props = props;
        this.limiter = limiter;
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
