package edu.bingol.backend.forum.topic;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kaydet (forum_bookmark: TOPIC | COMMENT). Tabloyu ve satir islemlerini A tanimlar; yorum kaydetmeyi B, kaydedilenler
 * listesini E bu servisle kullanir. Idempotent: satir zaten varsa/yoksa degisiklik olmaz. Konu sayaci
 * ({@code bookmark_count}) yalniz TOPIC icin ve yalniz satir gercekten eklendiyse/silindiyse atomik degisir.
 * Hedefin gorunurlugu CAGIRANDA denetlenir.
 */
@Service
public class ForumBookmarkService {

    private final JdbcTemplate jdbc;
    private final ForumTopicRepository topics;
    private final ForumBookmarkRepository repo;

    public ForumBookmarkService(JdbcTemplate jdbc, ForumTopicRepository topics, ForumBookmarkRepository repo) {
        this.jdbc = jdbc;
        this.topics = topics;
        this.repo = repo;
    }

    /** @return true = yeni eklendi; false = zaten kayitliydi */
    @Transactional
    public boolean save(Long userId, String type, Long targetId) {
        int n = jdbc.update("INSERT INTO forum_bookmark (user_id, target_type, target_id, created_at) "
                + "SELECT CAST(? AS BIGINT), CAST(? AS VARCHAR(10)), CAST(? AS BIGINT), CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM forum_bookmark WHERE user_id = ? AND target_type = ? AND target_id = ?)",
                userId, type, targetId, userId, type, targetId);
        if (n == 1 && ForumBookmark.TOPIC.equals(type)) {
            topics.addBookmarks(targetId, 1);
        }
        return n == 1;
    }

    /** @return true = silindi; false = zaten yoktu */
    @Transactional
    public boolean unsave(Long userId, String type, Long targetId) {
        int n = jdbc.update("DELETE FROM forum_bookmark WHERE user_id = ? AND target_type = ? AND target_id = ?",
                userId, type, targetId);
        if (n == 1 && ForumBookmark.TOPIC.equals(type)) {
            topics.addBookmarks(targetId, -1);
        }
        return n == 1;
    }

    @Transactional(readOnly = true)
    public Set<Long> savedAmong(Long userId, String type, Collection<Long> targetIds) {
        if (userId == null || targetIds == null || targetIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(repo.savedAmong(userId, type, targetIds));
    }

    /** KVKK: kullanicinin kayitlari silinir, konu sayaclari duser. */
    @Transactional
    public int purgeUser(Long userId) {
        jdbc.update("UPDATE forum_topic SET bookmark_count = bookmark_count - 1 WHERE bookmark_count > 0 AND id IN "
                + "(SELECT target_id FROM forum_bookmark WHERE user_id = ? AND target_type = 'TOPIC')", userId);
        return jdbc.update("DELETE FROM forum_bookmark WHERE user_id = ?", userId);
    }
}
