package edu.bingol.backend.observability;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Olu (DEAD) mail/push kayitlarini listeler, yeniden kuyruga alir ya da siler. Tablo adlari sabittir; durum her
 * zaman 'DEAD' ile sinirlanir (canli kayda dokunulmaz). Listelerde e-posta maskelenir, hata metni temizlenir,
 * icerik (mail degiskenleri, push govdesi) HIC donmez.
 */
@Service
public class DeadLetterService {

    public static final int MAX_LIMIT = 200;
    public static final int MAX_IDS = 500;

    public record MailDead(long id, String template, String to, int attempts, String lastError, Instant createdAt) {
    }

    public record PushDead(long id, Long userId, int attempts, String lastError, Instant createdAt) {
    }

    private final NamedParameterJdbcTemplate jdbc;

    public DeadLetterService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<MailDead> listMail(int limit) {
        return jdbc.query("SELECT id, template, to_address, attempts, last_error, created_at FROM mail_outbox "
                        + "WHERE status = 'DEAD' ORDER BY id DESC LIMIT :n",
                Map.of("n", clamp(limit)),
                (rs, i) -> new MailDead(rs.getLong("id"), rs.getString("template"),
                        LogMasking.email(rs.getString("to_address")), rs.getInt("attempts"),
                        LogMasking.scrub(rs.getString("last_error")), instant(rs.getTimestamp("created_at"))));
    }

    public List<PushDead> listPush(int limit) {
        return jdbc.query("SELECT id, user_id, attempts, last_error, created_at FROM push_outbox "
                        + "WHERE status = 'DEAD' ORDER BY id DESC LIMIT :n",
                Map.of("n", clamp(limit)),
                (rs, i) -> new PushDead(rs.getLong("id"), (Long) rs.getObject("user_id"), rs.getInt("attempts"),
                        LogMasking.scrub(rs.getString("last_error")), instant(rs.getTimestamp("created_at"))));
    }

    /** Kod postasi bu sureden eskiyse yeniden gonderilmez (kod 10 dk gecerli; MailOutboxAdminService.CODE_MAX_AGE ile ayni). */
    static final Duration CODE_MAX_AGE = Duration.ofMinutes(10);

    /**
     * Yeniden kuyruga alinabilen mail: DEAD olurken degiskenler temizlenir ({}), bos degiskenle gonderim kodsuz/
     * bos posta uretirdi. Bu yuzden icerigi yeniden uretilemeyenler (degiskeni silinmis, ACCOUNT_DELETED haric)
     * ve suresi dolmus kod postalari kuyruga ALINMAZ.
     */
    private static final String MAIL_RETRYABLE = " AND (template = 'ACCOUNT_DELETED' OR (vars_json IS NOT NULL "
            + "AND TRIM(vars_json) NOT IN ('', '{}'))) "
            + "AND NOT (template IN ('VERIFICATION_CODE', 'PASSWORD_RESET_CODE') AND created_at < :codeCutoff)";

    /** Mail yeniden deneme sonucu: kuyruga alinan ve icerigi artik uretilemedigi icin reddedilen (acik) sayilar. */
    public record MailRetryResult(int requeued, int skipped) {
    }

    /**
     * ids bos/null = tum olu kayitlar. Yeniden gonderilemeyenler (icerik silinmis / bayat kod) degistirilmez,
     * {@code skipped} olarak raporlanir.
     */
    @Transactional
    public MailRetryResult retryMail(List<Long> ids) {
        Instant now = Instant.now();
        Map<String, Object> extra = Map.of("codeCutoff", Timestamp.from(now.minus(CODE_MAX_AGE)));
        int total = count("SELECT COUNT(*) FROM mail_outbox WHERE status = 'DEAD'", ids);
        int requeued = update("UPDATE mail_outbox SET status = 'PENDING', attempts = 0, next_attempt_at = :now, "
                + "last_error = NULL WHERE status = 'DEAD'" + MAIL_RETRYABLE, ids, extra);
        return new MailRetryResult(requeued, Math.max(0, total - requeued));
    }

    @Transactional
    public int retryPush(List<Long> ids) {
        return update("UPDATE push_outbox SET status = 'PENDING', attempts = 0, next_attempt_at = :now, "
                + "lease_until = NULL WHERE status = 'DEAD'", ids, Map.of());
    }

    /** Silme yalniz acik kimliklerle (tumunu silmek icin once listelenmeli): kazara toplu silmeyi onler. */
    @Transactional
    public int deleteMail(List<Long> ids) {
        return delete("DELETE FROM mail_outbox WHERE status = 'DEAD'", ids);
    }

    @Transactional
    public int deletePush(List<Long> ids) {
        return delete("DELETE FROM push_outbox WHERE status = 'DEAD'", ids);
    }

    private int count(String sql, List<Long> ids) {
        if (ids != null && !ids.isEmpty()) {
            Integer n = jdbc.queryForObject(sql + " AND id IN (:ids)", Map.of("ids", ids), Integer.class);
            return n == null ? 0 : n;
        }
        Integer n = jdbc.queryForObject(sql, Map.of(), Integer.class);
        return n == null ? 0 : n;
    }

    private int update(String sql, List<Long> ids, Map<String, Object> extra) {
        Map<String, Object> p = new HashMap<>(extra);
        p.put("now", Timestamp.from(Instant.now()));
        if (ids != null && !ids.isEmpty()) {
            p.put("ids", ids);
            return jdbc.update(sql + " AND id IN (:ids)", p);
        }
        return jdbc.update(sql, p);
    }

    private int delete(String sql, List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return 0;
        }
        return jdbc.update(sql + " AND id IN (:ids)", Map.of("ids", ids));
    }

    private static int clamp(int limit) {
        return Math.max(1, Math.min(limit, MAX_LIMIT));
    }

    private static Instant instant(Timestamp t) {
        return t == null ? null : t.toInstant();
    }
}
