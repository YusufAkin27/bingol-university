package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.export.DataExporter;
import java.time.Clock;
import java.time.Duration;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import edu.bingol.backend.user.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Kullanici ADINA KVKK dis aktarma (yonetici). Bolumler kullanicinin kendi "verilerimi indir" ucuyla ayni
 * {@link DataExporter} bean'lerinden gelir. Guvenlik: sebep en az {@value AdminGuardPolicy#EXPORT_MIN_REASON}
 * karakter + ikinci onay (hedef kullanici kimligini yazdirma, `X-Admin-Confirm`) + kullanici basina gunde en cok bir
 * kez. Kullaniciya bildirim GITMEZ; islem denetim kaydina yazilir (AuditInterceptor, POST).
 */
@Service
public class AdminUserExportService {

    private static final Logger log = LoggerFactory.getLogger(AdminUserExportService.class);

    private final List<DataExporter> exporters;
    private final UserRepository users;
    private final RateLimiter limiter;
    private final Clock clock;

    public AdminUserExportService(List<DataExporter> exporters, UserRepository users, RateLimiter limiter, Clock clock) {
        this.exporters = exporters.stream().sorted(Comparator.comparing(DataExporter::section)).toList();
        this.users = users;
        this.limiter = limiter;
        this.clock = clock;
    }

    /** Dogrulamalar once (basarisiz istek gunluk hakki tuketmez), sonra hak tuketilir, sonra bolumler toplanir. */
    public Map<String, Object> export(Long targetId, String reason, String confirm) {
        Targets.reason(reason, AdminGuardPolicy.EXPORT_MIN_REASON);
        if (confirm == null || !confirm.strip().equals(String.valueOf(targetId))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EXPORT_CONFIRM_MISMATCH",
                    "İkinci onay eksik: kullanıcı kimliğini onay başlığına yazın.");
        }
        Targets.active(users, targetId);
        // Hedef kullanici basina gunde bir: sabit pencere (24 sa); ikinci istek 429 + Retry-After.
        limiter.check("admexp:" + targetId, 1, Duration.ofDays(1));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("exportedAt", clock.instant().toString());
        out.put("subjectUserId", targetId);
        for (DataExporter e : exporters) {
            // Tek bolumun hatasi butun indirmeyi 500'e dusurmesin (DataExportController ile ayni)
            try {
                out.put(e.section(), e.export(targetId));
            } catch (RuntimeException ex) {
                log.warn("yonetici veri disa aktarim bolumu basarisiz ({}): {}", e.section(), ex.toString());
                out.put(e.section(), Map.of("error", "SECTION_UNAVAILABLE"));
            }
        }
        return out;
    }
}
