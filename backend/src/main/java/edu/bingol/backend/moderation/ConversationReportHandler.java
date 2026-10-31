package edu.bingol.backend.moderation;

import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * CONVERSATION hedefi (T-057, A16-11): GRUP sohbetinin kendisi (baslik/avatar/toplu uye kaynakli taciz). Hedef kimligi =
 * sohbet kimligi; yalniz aktif uye raporlayabilir (uye olmayan icin 404). Bireysel sohbet bu turle raporlanmaz
 * (mesaj/kullanici raporu kullanilir). "Gizle" = sohbet yonetici gibi KAPATILIR (yeni mesaj gonderilemez, gecmis ve
 * uyelikler korunur; bkz. Conversation.closedAt). Geri alinamaz sayilir: otomatik kapatma yok, yalniz yonetici karari.
 * Duz SQL: messaging paketine bagimlilik yok.
 */
@Component
public class ConversationReportHandler implements ReportTargetHandler {

    static final String REASON = "Şikayet sonucu kapatıldı";

    private final JdbcTemplate jdbc;

    public ConversationReportHandler(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.CONVERSATION;
    }

    @Override
    public boolean exists(Long targetId) {
        return count("SELECT COUNT(*) FROM conversation WHERE id = ? AND type = 'GROUP'", targetId) > 0;
    }

    @Override
    public boolean exists(Long viewerId, Long targetId) {
        if (viewerId == null) {
            return exists(targetId);
        }
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM conversation c JOIN conversation_member m "
                + "ON m.conversation_id = c.id WHERE c.id = ? AND c.type = 'GROUP' AND m.user_id = ? "
                + "AND m.left_at IS NULL", Long.class, targetId, viewerId);
        return n != null && n > 0;
    }

    /** Sahip = grubu olusturan (rol ADMIN uyeler birden cok olabilir; ihlal kaydi kurucuya yazilir). */
    @Override
    public Optional<Long> ownerId(Long targetId) {
        List<Long> r = jdbc.queryForList("SELECT created_by FROM conversation WHERE id = ? AND type = 'GROUP'",
                Long.class, targetId);
        return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        jdbc.update("UPDATE conversation SET closed_at = CURRENT_TIMESTAMP, closed_reason = ? "
                + "WHERE id = ? AND type = 'GROUP' AND closed_at IS NULL", REASON, targetId);
    }

    private long count(String sql, Object arg) {
        Long n = jdbc.queryForObject(sql, Long.class, arg);
        return n == null ? 0 : n;
    }
}
