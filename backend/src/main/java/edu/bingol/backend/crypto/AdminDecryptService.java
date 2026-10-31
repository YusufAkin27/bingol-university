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
 * Gerekce: istekteki gercek sebep ({@link #currentReason()}); yoksa sistem sabit gerekce yazar (veritabani kisiti >= 10 karakter ister).
 */
@Service
public class AdminDecryptService {

    private static final Logger log = LoggerFactory.getLogger(AdminDecryptService.class);

    /** Sohbet icerigi icin en kisa gercek sebep uzunlugu (T-015; veritabani kisiti en az 10 ister, burasi daha siki). */
    public static final int MIN_REASON = 20;

    /** `app.admin.require-reason` (varsayilan acik; testlerde kapali). */
    @org.springframework.beans.factory.annotation.Value("${app.admin.require-reason:true}")
    private boolean requireReason = true;

    /** Denetim kaydina yazilan sabit gerekce (>= 10 karakter). */
    public static final String SYSTEM_REASON = "yonetici sohbet goruntuleme";

    /**
     * Denetim kaydina yazilacak gerekce: istekte verilen GERCEK sebep (X-Admin-Reason / reason; yonetici sohbet uclari
     * bunu zorunlu tutar, en az 10 karakter), yoksa (istek disi/birim testi ya da zorunluluk kapali) sabit sistem gerekcesi.
     */
    public static String currentReason() {
        String r = edu.bingol.backend.admin.AuditContext.currentReason();
        return r != null && r.strip().length() >= MIN_REASON ? r.strip() : SYSTEM_REASON;
    }

    /** Cozme sonucu: text bos ise cozme basarisizdir (error dolu, CryptoException nedeni). */
    public record Plain(String text, String error) {}

    private final CryptoProperties props;
    private final MessageCipher cipher;
    private final MessageAccessAuditRepository audit;

    /** Saatlik kota icin (istege bagli: yalniz birim testlerinde yok). */
    private edu.bingol.backend.common.RateLimiter limiter;

    public AdminDecryptService(CryptoProperties props, MessageCipher cipher, MessageAccessAuditRepository audit) {
        this.props = props;
        this.cipher = cipher;
        this.audit = audit;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setLimiter(edu.bingol.backend.common.RateLimiter limiter) {
        this.limiter = limiter;
    }

    /** Ayar kapaliysa 403 ADMIN_DECRYPT_DISABLED. */
    public void requireEnabled() {
        if (!props.adminDecryptEnabled()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ADMIN_DECRYPT_DISABLED", "Yönetici mesaj çözme kapalı.");
        }
    }

    /**
     * Istek baglaminda (HTTP) icerik acmadan once GERCEK sebep ister: `X-Admin-Reason` / `reason` en az
     * {@value #MIN_REASON} karakter, yoksa 400 REASON_REQUIRED. `app.admin.require-reason=false` ya da istek disi
     * cagrida (birim testi, zamanlayici) zorlanmaz; sebep yoksa sistem gerekcesi yazilir.
     */
    public void requireReason() {
        if (!requireReason || !(org.springframework.web.context.request.RequestContextHolder.getRequestAttributes()
                instanceof org.springframework.web.context.request.ServletRequestAttributes)) {
            return;
        }
        String r = edu.bingol.backend.admin.AuditContext.currentReason();
        if (r == null || r.strip().length() < MIN_REASON) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + MIN_REASON + " karakter).", String.valueOf(MIN_REASON));
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

    /**
     * Yonetici basina saatlik cozme kotasi (`app.crypto.admin-decrypt-per-hour`, istek sayisi) ve tek cagrida cozulebilecek
     * en cok mesaj (`admin-decrypt-max-messages`). Kota asilirsa 429 RATE_LIMITED (Retry-After) ve ICERIK DONMEZ (T-015).
     */
    void enforceQuota(List<Entry> entries) {
        if (entries == null || entries.isEmpty()) {
            return;
        }
        int max = props.adminDecryptMaxMessages();
        int total = entries.stream().mapToInt(Entry::messageCount).sum();
        if (max > 0 && total > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "DECRYPT_BATCH_TOO_LARGE",
                    "Tek istekte en fazla " + max + " mesaj çözülebilir.", String.valueOf(max));
        }
        if (limiter != null && props.adminDecryptPerHour() > 0) {
            limiter.check("admindecrypt:" + entries.get(0).adminId(), props.adminDecryptPerHour(),
                    java.time.Duration.ofHours(1));
        }
    }

    /** Erisimleri denetim kaydina yazar; yazilamazsa 503 CRYPTO_UNAVAILABLE (cagiran duz metni DONMEMELI). */
    public void record(List<Entry> entries, String ip) {
        enforceQuota(entries);
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
