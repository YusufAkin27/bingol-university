package edu.bingol.backend.crypto;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.MessageAccessAuditRepository.Entry;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Yonetici sohbet goruntuleyicisinin sifre cozme + denetim cekirdegi (T24). Kurallar: ayar acik; duz metin
 * istemciye DONMEDEN ONCE degistirilemez denetim kaydi yazilir (kayit yazilamazsa 503 ve hicbir icerik donmez).
 * Gerekce girisi yoktur; sistem sabit gerekce yazar (veritabani kisiti >= 10 karakter ister).
 */
@Service
public class AdminDecryptService {

    private static final Logger log = LoggerFactory.getLogger(AdminDecryptService.class);

    /** Denetim kaydina yazilan sabit gerekce (>= 10 karakter). */
    public static final String SYSTEM_REASON = "yonetici sohbet goruntuleme";

    /** Cozme sonucu: text bos ise cozme basarisizdir (error dolu, CryptoException nedeni). */
    public record Plain(String text, String error) {}

    private final CryptoProperties props;
    private final MessageCipher cipher;
    private final MessageAccessAuditRepository audit;

    public AdminDecryptService(CryptoProperties props, MessageCipher cipher, MessageAccessAuditRepository audit) {
        this.props = props;
        this.cipher = cipher;
        this.audit = audit;
    }

    /** Ayar kapaliysa 403 ADMIN_DECRYPT_DISABLED. */
    public void requireEnabled() {
        if (!props.adminDecryptEnabled()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ADMIN_DECRYPT_DISABLED", "Yönetici mesaj çözme kapalı.");
        }
    }

    /** Tek sifreli govdeyi cozer; hata mesaj basina yutulur (tum sayfa bozulmasin), neden doner. */
    public Plain open(long conversationId, byte[] context, Sealed sealed) {
        if (sealed == null) {
            return new Plain(null, "NO_CIPHERTEXT");
        }
        try {
            return new Plain(cipher.decryptText(conversationId, context, sealed), null);
        } catch (CryptoException e) {
            return new Plain(null, e.reason().name());
        }
    }

    /** Erisimleri denetim kaydina yazar; yazilamazsa 503 CRYPTO_UNAVAILABLE (cagiran duz metni DONMEMELI). */
    public void record(List<Entry> entries, String ip) {
        try {
            audit.insertAll(entries);
        } catch (DataAccessException e) {
            log.error("Mesaj erisim denetimi yazilamadi; icerik donmuyor: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "CRYPTO_UNAVAILABLE",
                    "Şifreleme hizmeti şu anda kullanılamıyor.");
        }
        if (!entries.isEmpty()) {
            Entry f = entries.get(0);
            log.info("Yonetici sohbet goruntuledi: admin={} hedef={} kayit={} tur={} ip={}", f.adminId(), f.targetUserId(),
                    entries.size(), f.kind(), ip);
        }
    }
}
