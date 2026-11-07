package edu.bingol.backend.forum.comment;

import edu.bingol.backend.common.ApiException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Yorum durum gecisleri ve sayac sonuclari TEK yerde: sahibi silme, moderator kaldirma/geri alma, hesap silme.
 * Cagiran kendi islemini (transaction) acar ve satiri FOR UPDATE ile kilitlemis olmalidir; sayaclar atomik UPDATE.
 *
 * <p>Durumlar: CANLI (deleted_at null, ACTIVE) | MEZAR TASI (deleted_at dolu ya da REMOVED). Mezar tasi altinda
 * listelenen yaniti varsa yer tutucu olarak listelenir, yoksa listeden cikar (ust yorumun reply_count'u duser; ust de
 * yer tutucuysa ve boslasa zincir yukari cikar).
 */
@Component
class ForumCommentLifecycle {

    /** Silinen yorumun DB'deki govdesi (KVKK: metin tutulmaz; iz olarak satir kalir). */
    static final String DELETED_BODY = "[silindi]";

    private final JdbcTemplate jdbc;
    private final ForumCommentCounters counters;
    private final ForumCommentStore store;

    ForumCommentLifecycle(JdbcTemplate jdbc, ForumCommentCounters counters, ForumCommentStore store) {
        this.jdbc = jdbc;
        this.counters = counters;
        this.store = store;
    }

    /** Sahibi (ya da hesap silme) siler: govde temizlenir, satir iz olarak kalir. @param r kilitli satir */
    void deleteByOwner(ForumCommentRow r) {
        if (r.deleted()) {
            return;
        }
        jdbc.update("UPDATE forum_comment SET deleted_at = ?, updated_at = ?, body = ? WHERE id = ? AND deleted_at IS NULL",
                now(), now(), DELETED_BODY, r.id());
        if (r.live()) {
            tombstoned(r);
        }
        // r REMOVED idiyse zaten sayilmiyordu ve listeleme durumu degismez (yalniz govde temizlendi)
    }

    /** Moderator kaldirir. Zaten mezar tasiysa hicbir sey yapmaz. @param r kilitli satir */
    void remove(ForumCommentRow r, String reason) {
        if (!r.live()) {
            return;
        }
        String why = reason == null ? null : reason.length() > 500 ? reason.substring(0, 500) : reason;
        jdbc.update("UPDATE forum_comment SET status = 'REMOVED', removed_reason = ?, removed_at = ?, updated_at = ? "
                + "WHERE id = ? AND status = 'ACTIVE' AND deleted_at IS NULL", why, now(), now(), r.id());
        tombstoned(r);
    }

    /** Moderator kaldirmasini geri alir. @throws ApiException 409 sahibi silmisse. @param r kilitli satir */
    void restore(ForumCommentRow r) {
        if (r.deleted()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_COMMENT_DELETED", "Bu yorum sahibi tarafından silinmiş.");
        }
        if (!r.removed()) {
            return;
        }
        jdbc.update("UPDATE forum_comment SET status = 'ACTIVE', removed_reason = NULL, removed_at = NULL, updated_at = ? "
                + "WHERE id = ? AND status = 'REMOVED' AND deleted_at IS NULL", now(), r.id());
        if (r.replyCount() == 0) {
            counters.relisted(r); // yer tutucu bile degildi: listeye geri girdi
        }
        counters.topicComments(r.topicId(), 1, false);
    }

    /** Canli yorum mezar tasina donustu (satir zaten guncellendi): listeleme + konu sayaci. */
    private void tombstoned(ForumCommentRow r) {
        if (r.replyCount() == 0) {
            counters.unlisted(r);
        }
        // Konu satiri EN SON (kilit sirasi)
        counters.topicComments(r.topicId(), -1, false);
    }

    /** Hesap silme: bir kullanicinin tum yorumlarinin metnini temizle (canli olanlar mezar tasi olur). */
    int purgeUserComments(long userId) {
        int total = 0;
        List<Long> ids;
        int guard = 0;
        do {
            ids = jdbc.queryForList("SELECT id FROM forum_comment WHERE user_id = ? AND deleted_at IS NULL "
                    + "ORDER BY id DESC LIMIT 500", Long.class, userId);
            for (Long id : ids) {
                ForumCommentRow r = store.findForUpdate(id).orElse(null);
                if (r != null) {
                    deleteByOwner(r);
                    total++;
                }
            }
        } while (!ids.isEmpty() && ++guard < 10_000);
        jdbc.update("UPDATE forum_comment SET idempotency_key = NULL WHERE user_id = ? AND idempotency_key IS NOT NULL", userId);
        return total;
    }

    private static Timestamp now() {
        return Timestamp.from(Instant.now());
    }
}
