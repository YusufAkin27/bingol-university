package edu.bingol.backend.common;

import java.util.Optional;
import java.util.function.Function;
import java.util.function.Supplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Olusturma uclari icin kalici Idempotency-Key (V1610). Baslik yoksa {@code create} aynen calisir (eski davranis).
 * Varsa: onceden ayni (kullanici, kapsam, anahtar) ile olusmus kayit varsa {@code replay(id)} doner ve hiz sinirina
 * sayilmaz; yoksa {@code create} ile kayit defteri satiri AYNI islemde yazilir. Es zamanli cift gonderimde ikinci
 * islem benzersiz ihlaliyle geri alinir ve kazananin kaydi doner.
 */
@Component
public class IdempotentCreate {

    private static final Logger log = LoggerFactory.getLogger(IdempotentCreate.class);
    static final String KEY_PATTERN = "[A-Za-z0-9_-]{8,64}";

    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public IdempotentCreate(JdbcTemplate jdbc, PlatformTransactionManager tm) {
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
    }

    /** Bean yoksa (birim testleri) korumasiz calisir; denetleyiciler setter ile istege bagli enjekte eder. */
    public static <T> T exec(IdempotentCreate idem, Long uid, String scope, String rawKey, Runnable before, Supplier<T> create,
                             Function<T, Long> idOf, Function<Long, T> replay) {
        if (idem == null) {
            before.run();
            return create.get();
        }
        return idem.run(uid, scope, rawKey, before, create, idOf, replay);
    }

    /** 8-64 karakter, harf/rakam/tire/alt cizgi; bos ise null (korumasiz). */
    static String cleanKey(String key) {
        if (key == null || key.isBlank()) {
            return null;
        }
        String k = key.trim();
        if (!k.matches(KEY_PATTERN)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "IDEMPOTENCY_KEY_INVALID", "Geçersiz Idempotency-Key.");
        }
        return k;
    }

    /**
     * @param before   yeni kayit yolunda (replay degilse) once calisir: hiz siniri gibi
     * @param create   kaynagi olusturur
     * @param idOf     olusan kaynagin kimligi
     * @param replay   kimlikten ayni yaniti uretir
     */
    public <T> T run(Long uid, String scope, String rawKey, Runnable before, Supplier<T> create,
                     Function<T, Long> idOf, Function<Long, T> replay) {
        String key = cleanKey(rawKey);
        if (key == null) {
            before.run();
            return create.get();
        }
        Optional<Long> prior = find(uid, scope, key);
        if (prior.isPresent()) {
            return replay.apply(prior.get());
        }
        before.run();
        try {
            return tx.execute(st -> {
                T out = create.get();
                jdbc.update("INSERT INTO idempotency_record (user_id, scope, idem_key, resource_id) VALUES (?,?,?,?)",
                        uid, scope, key, idOf.apply(out));
                return out;
            });
        } catch (DataIntegrityViolationException e) {
            Optional<Long> winner = find(uid, scope, key);
            if (winner.isEmpty()) {
                throw e;
            }
            return replay.apply(winner.get());
        }
    }

    Optional<Long> find(Long uid, String scope, String key) {
        return jdbc.queryForList("SELECT resource_id FROM idempotency_record WHERE user_id = ? AND scope = ? AND idem_key = ?",
                Long.class, uid, scope, key).stream().findFirst();
    }

    /** Gece 03:40: 7 gunden eski satirlar (anahtarlar kisa omurludur). */
    @Scheduled(cron = "${app.idempotency.cleanup-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
    public void cleanup() {
        try {
            int n = jdbc.update("DELETE FROM idempotency_record WHERE created_at < now() - interval '7 days'");
            if (n > 0) {
                log.info("idempotency_record temizligi: {} satir", n);
            }
        } catch (RuntimeException e) {
            log.warn("idempotency_record temizligi basarisiz: {}", e.toString());
        }
    }
}
