package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.bulk.BulkDtos.Report;
import edu.bingol.backend.admin.bulk.BulkSupport.Tally;
import edu.bingol.backend.auth.LoginIdentifier;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.common.ApiException;
import java.util.LinkedHashSet;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Bekleyen (dogrulanmamis) kayitlari toplu iptal eder: Redis `reg:<e-posta>` anahtari TAM e-posta ile saklanir (hash
 * degil); kimlik e-posta ya da okul numarasi gelebilir ve normalize edilir. Sonuc listesinde kimlik MASKELIDIR.
 * Hesap olusmadigi icin geri alinacak veri yoktur; kullanici yeniden kayit olabilir.
 */
@Service
public class PendingBulkService {

    private static final Logger log = LoggerFactory.getLogger(PendingBulkService.class);

    private final PendingRegistrationStore store;

    public PendingBulkService(PendingRegistrationStore store) {
        this.store = store;
    }

    /** Kimlikleri normalize eder (tekrarlar atilir); gecersiz kimlik -> 400 VALIDATION_ERROR (hicbiri silinmez). */
    public static List<String> normalize(List<String> raw) {
        LinkedHashSet<String> out = new LinkedHashSet<>();
        for (String s : raw) {
            out.add(LoginIdentifier.normalize(s));
        }
        return List.copyOf(out);
    }

    public Report cancel(List<String> emails) {
        Tally t = new Tally();
        for (String email : emails) {
            String masked = BulkSupport.maskEmail(email);
            try {
                if (store.remove(email)) {
                    t.done(masked);
                } else {
                    t.skipped(masked, "NOT_FOUND");
                }
            } catch (ApiException e) {
                t.failed(masked, e.code());
            } catch (RuntimeException e) {
                log.warn("Toplu bekleyen kayit iptali hatasi: {}", e.toString());
                t.failed(masked, "INTERNAL_ERROR");
            }
        }
        return t.report();
    }
}
