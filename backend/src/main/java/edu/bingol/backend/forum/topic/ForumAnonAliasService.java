package edu.bingol.backend.forum.topic;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * (konu, kullanici) basina kararli anonim takma ad numarasi. Atomik tahsis: {@code INSERT .. SELECT MAX(n)+1};
 * (konu, n) benzersiz kisiti yarisan ikinci tahsisi reddeder, kaybeden yeniden dener (satirin kendisi zaten varsa
 * onu okur). Numara konu icinde 1'den baslar ve atlama/yineleme olmaz (silinme yok).
 */
@Service
public class ForumAnonAliasService {

    private static final Logger log = LoggerFactory.getLogger(ForumAnonAliasService.class);
    private static final int MAX_ATTEMPTS = 25;

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final TransactionTemplate isolated;

    public ForumAnonAliasService(JdbcTemplate jdbc, PlatformTransactionManager tm) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
        this.isolated = new TransactionTemplate(tm);
        this.isolated.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    /**
     * Konu olusturma islemi ICINDE (konu satiri henuz commit edilmemisken) tahsis: ayri islem acmaz, yarisan baska
     * yazici olamaz (konuyu yalniz olusturan bilir).
     */
    public int allocateInCurrentTx(Long topicId, Long userId) {
        Integer existing = find(topicId, userId);
        if (existing != null) {
            return existing;
        }
        jdbc.update("INSERT INTO forum_anon_alias (topic_id, user_id, n) SELECT CAST(? AS BIGINT), CAST(? AS BIGINT), COALESCE(MAX(n), 0) + 1 "
                + "FROM forum_anon_alias WHERE topic_id = ?", topicId, userId, topicId);
        Integer n = find(topicId, userId);
        return n == null ? 0 : n;
    }

    /**
     * Mevcut konuda (yorum yazarken) tahsis; baska islemlerle yarisabilir: kendi islemi (REQUIRES_NEW) icinde
     * yeniden dener. Sonuc commit edilir (cagiranin islemi geri alinsa da numara konu icinde yer tutar; zararsiz).
     */
    public int aliasFor(Long topicId, Long userId) {
        Integer existing = find(topicId, userId);
        if (existing != null) {
            return existing;
        }
        for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
            try {
                Integer n = isolated.execute(st -> {
                    Integer cur = find(topicId, userId);
                    if (cur != null) {
                        return cur;
                    }
                    jdbc.update("INSERT INTO forum_anon_alias (topic_id, user_id, n) SELECT CAST(? AS BIGINT), CAST(? AS BIGINT), COALESCE(MAX(n), 0) + 1 "
                            + "FROM forum_anon_alias WHERE topic_id = ?", topicId, userId, topicId);
                    return find(topicId, userId);
                });
                if (n != null) {
                    return n;
                }
            } catch (DataAccessException e) {
                // (konu, n) ya da (konu, kullanici) cakismasi: baska islem once yazdi; kendi satirimiz varsa onu al
                Integer cur = find(topicId, userId);
                if (cur != null) {
                    return cur;
                }
                log.debug("Anonim takma ad tahsisi yeniden denenecek (konu {}): {}", topicId, e.toString());
                try {
                    Thread.sleep(java.util.concurrent.ThreadLocalRandom.current().nextInt(1, 15)); // cakisanlar dagilsin
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
        throw new IllegalStateException("Anonim takma ad tahsis edilemedi: konu " + topicId);
    }

    /** Verilen kullanicilarin bu konudaki mevcut numaralari (tahsis etmez). */
    public Map<Long, Integer> existing(Long topicId, Collection<Long> userIds) {
        Map<Long, Integer> out = new HashMap<>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }
        List<Map<String, Object>> rows = named.queryForList(
                "SELECT user_id, n FROM forum_anon_alias WHERE topic_id = :t AND user_id IN (:u)",
                new MapSqlParameterSource("t", topicId).addValue("u", userIds));
        for (Map<String, Object> r : rows) {
            out.put(((Number) r.get("user_id")).longValue(), ((Number) r.get("n")).intValue());
        }
        return out;
    }

    private Integer find(Long topicId, Long userId) {
        List<Integer> r = jdbc.queryForList("SELECT n FROM forum_anon_alias WHERE topic_id = ? AND user_id = ?",
                Integer.class, topicId, userId);
        return r.isEmpty() ? null : r.get(0);
    }
}
