package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.forum.moderation.ForumContentLookup.CommentRow;
import edu.bingol.backend.forum.moderation.ForumContentLookup.TopicRow;
import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import edu.bingol.backend.moderation.ModerationTargetState;
import edu.bingol.backend.moderation.ModerationTargetStateRepository;
import edu.bingol.backend.moderation.ReportTargetType;
import java.time.Instant;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Forum moderator eylemleri. Durum gecisleri SUNUCUDA dogrulanir (gecersiz gecis 409 FORUM_INVALID_STATE); durumu
 * degistiren is A (konu) / B (yorum) servislerindedir ({@link ForumStatePort}), burada yalniz karar + kayit + rapor
 * kuyrugu tutarliligi vardir. Yetki kontrolu cagirana aittir (kullanici API'si: izin forum.moderate; yonetici API'si:
 * AdminPermissionInterceptor).
 */
@Service
public class ForumModerationService {

    private static final Logger log = LoggerFactory.getLogger(ForumModerationService.class);

    public enum Action {
        PIN, UNPIN, LOCK, UNLOCK, REMOVE, RESTORE;

        public boolean needsReason() {
            return this == REMOVE || this == RESTORE;
        }
    }

    /** Eylem sonrasi hedefin durumu (istemci ekrani guncellemek icin). */
    public record Result(String targetType, Long targetId, String action, String status, boolean pinned, boolean locked) {}

    static final int MAX_REASON = 300;
    /** Eszamanli sabitlenebilecek konu ust siniri (ForumFeedService.MAX_PINNED ile ayni). */
    static final int MAX_PINNED = 5;

    private final ForumContentLookup content;
    private final ForumStatePort port;
    private final ForumModerationActionRepository actions;
    private final ModerationTargetStateRepository states;
    private final JdbcTemplate jdbc;

    public ForumModerationService(ForumContentLookup content, ForumStatePort port, ForumModerationActionRepository actions,
                                  ModerationTargetStateRepository states, JdbcTemplate jdbc) {
        this.content = content;
        this.port = port;
        this.actions = actions;
        this.states = states;
        this.jdbc = jdbc;
    }

    // --- dogrudan moderator eylemi ---

    @Transactional
    public Result moderateTopic(Long actorId, Long topicId, Action action, String rawReason) {
        String reason = reason(action, rawReason);
        TopicRow t = content.topic(topicId).filter(r -> !r.deleted()).orElseThrow(ForumModerationService::notFound);
        switch (action) {
            case PIN -> {
                require(t.active() && !t.pinned());
                // Akis en cok MAX_PINNED sabitlenmisi gosterir: fazlasi Sana Ozel/En Yeni'de hic gorunmezdi (QA5-07)
                Long pinnedNow = jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic WHERE pinned_at IS NOT NULL "
                        + "AND deleted_at IS NULL AND status = 'ACTIVE'", Long.class);
                if (pinnedNow != null && pinnedNow >= MAX_PINNED) {
                    throw new ApiException(HttpStatus.CONFLICT, "FORUM_PIN_LIMIT",
                            "En fazla " + MAX_PINNED + " konu sabitlenebilir. Önce birini kaldırın.", String.valueOf(MAX_PINNED));
                }
                port.pinTopic(topicId);
            }
            case UNPIN -> {
                require(t.pinned());
                port.unpinTopic(topicId);
            }
            case LOCK -> {
                require(t.active() && !t.locked());
                port.lockTopic(topicId);
            }
            case UNLOCK -> {
                require(t.locked());
                port.unlockTopic(topicId);
            }
            case REMOVE -> {
                require(t.active());
                port.removeTopic(topicId, reason);
                closeReports(ReportTargetType.FORUM_TOPIC, topicId, actorId);
            }
            case RESTORE -> {
                require(t.removed());
                port.restoreTopic(topicId);
                clearHidden(ReportTargetType.FORUM_TOPIC, topicId);
            }
        }
        record("FORUM_TOPIC", topicId, topicId, action, reason, actorId, ForumModerationActionRecord.SOURCE_MODERATOR);
        port.publishModeration("TOPIC", topicId, topicId, action.name(), reason);
        TopicRow after = content.topic(topicId).orElse(t);
        return new Result("FORUM_TOPIC", topicId, action.name(), after.status(), after.pinned(), after.locked());
    }

    @Transactional
    public Result moderateComment(Long actorId, Long commentId, Action action, String rawReason) {
        if (action != Action.REMOVE && action != Action.RESTORE) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_ACTION_INVALID", "Bu eylem yorumlar için geçerli değil.");
        }
        String reason = reason(action, rawReason);
        CommentRow c = content.comment(commentId).filter(r -> !r.deleted()).orElseThrow(ForumModerationService::notFound);
        if (action == Action.REMOVE) {
            require(c.active());
            port.removeComment(commentId, reason);
            closeReports(ReportTargetType.FORUM_COMMENT, commentId, actorId);
        } else {
            require(c.removed());
            port.restoreComment(commentId);
            clearHidden(ReportTargetType.FORUM_COMMENT, commentId);
        }
        record("FORUM_COMMENT", commentId, c.topicId(), action, reason, actorId, ForumModerationActionRecord.SOURCE_MODERATOR);
        port.publishModeration("COMMENT", commentId, c.topicId(), action.name(), reason);
        CommentRow after = content.comment(commentId).orElse(c);
        return new Result("FORUM_COMMENT", commentId, action.name(), after.status(), false, false);
    }

    // --- rapor akisi (ReportTargetHandler.hide/unhide) ---

    /** Rapor sonucu/otomatik esik gizlemesi. Idempotent; bildirimi ModerationNotifier gonderir (burada olay YOK). */
    @Transactional
    public void hideFromReport(ReportTargetType type, Long targetId) {
        Long actor = adminActorOrNull();
        String source = actor == null ? ForumModerationActionRecord.SOURCE_REPORT_AUTO : ForumModerationActionRecord.SOURCE_REPORT;
        if (type == ReportTargetType.FORUM_TOPIC) {
            Optional<TopicRow> t = content.topic(targetId).filter(r -> !r.deleted());
            if (t.isPresent() && t.get().active()) {
                port.removeTopic(targetId, "Şikayet");
                record("FORUM_TOPIC", targetId, targetId, Action.REMOVE, "Şikayet", actor, source);
            }
        } else if (type == ReportTargetType.FORUM_COMMENT) {
            Optional<CommentRow> c = content.comment(targetId).filter(r -> !r.deleted());
            if (c.isPresent() && c.get().active()) {
                port.removeComment(targetId, "Şikayet");
                record("FORUM_COMMENT", targetId, c.get().topicId(), Action.REMOVE, "Şikayet", actor, source);
            }
        }
    }

    /** Gizlemeyi geri al (rapor reddi/itiraz/yonetici geri alma). Idempotent. */
    @Transactional
    public void restoreFromReport(ReportTargetType type, Long targetId) {
        Long actor = adminActorOrNull();
        String source = actor == null ? ForumModerationActionRecord.SOURCE_REPORT_AUTO : ForumModerationActionRecord.SOURCE_REPORT;
        if (type == ReportTargetType.FORUM_TOPIC) {
            Optional<TopicRow> t = content.topic(targetId).filter(r -> !r.deleted());
            if (t.isPresent() && t.get().removed()) {
                port.restoreTopic(targetId);
                record("FORUM_TOPIC", targetId, targetId, Action.RESTORE, "Şikayet kararı geri alındı", actor, source);
            }
        } else if (type == ReportTargetType.FORUM_COMMENT) {
            Optional<CommentRow> c = content.comment(targetId).filter(r -> !r.deleted());
            if (c.isPresent() && c.get().removed()) {
                port.restoreComment(targetId);
                record("FORUM_COMMENT", targetId, c.get().topicId(), Action.RESTORE, "Şikayet kararı geri alındı", actor, source);
            }
        }
    }

    // --- yardimcilar ---

    private String reason(Action action, String raw) {
        String r = raw == null ? null : ForumTextSanitizer.singleLine(raw);
        if (r != null && r.isEmpty()) {
            r = null;
        }
        if (action.needsReason() && r == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_REASON_REQUIRED", "Bu eylem için gerekçe zorunludur.");
        }
        if (r != null && r.length() > MAX_REASON) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_REASON_TOO_LONG", "Gerekçe en fazla 300 karakter olabilir.");
        }
        return r;
    }

    private static void require(boolean ok) {
        if (!ok) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_MOD_INVALID_STATE", "İçeriğin mevcut durumunda bu eylem yapılamaz.");
        }
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_MOD_TARGET_NOT_FOUND", "İçerik bulunamadı.");
    }

    private void record(String targetType, Long targetId, Long topicId, Action action, String reason, Long actor, String source) {
        ForumModerationActionRecord r = new ForumModerationActionRecord();
        r.setActorId(actor);
        r.setTargetType(targetType);
        r.setTargetId(targetId);
        r.setTopicId(topicId);
        r.setAction(action.name());
        r.setReason(reason);
        r.setSource(source);
        actions.save(r);
    }

    /**
     * Dogrudan kaldirma: bekleyen sikayetleri "HIDE" ile kapatir ve hedefi yonetici gizlemesi olarak isaretler (rapor
     * kuyrugu ve "gizlenen icerik" listesi tutarli kalir; geri alma HiddenContentAdminService uzerinden de calisir).
     * Strike/raporlayan bildirimi uretmez (bunlar rapor karariyla gelir).
     */
    private void closeReports(ReportTargetType type, Long targetId, Long actorId) {
        jdbc.update("UPDATE report SET status = 'RESOLVED', resolution = 'HIDE', resolved_by = ?, resolved_at = CURRENT_TIMESTAMP "
                + "WHERE target_type = ? AND target_id = ? AND status = 'OPEN'", actorId, type.name(), targetId);
        try {
            ModerationTargetState s = states.findByTargetTypeAndTargetId(type, targetId).orElseGet(() -> {
                ModerationTargetState n = new ModerationTargetState();
                n.setTargetType(type);
                n.setTargetId(targetId);
                return n;
            });
            s.setHiddenBy(ModerationTargetState.HiddenBy.ADMIN);
            if (s.getHiddenAt() == null) {
                s.setHiddenAt(Instant.now());
            }
            s.setUpdatedAt(Instant.now());
            states.save(s);
        } catch (DataIntegrityViolationException e) {
            log.debug("Gizleme durumu zaten yazilmis: {} #{}", type, targetId);
        }
    }

    private void clearHidden(ReportTargetType type, Long targetId) {
        states.clear(type, targetId);
    }

    /** Istek /api/admin/** uzerinden gelen yoneticiyse kimligi; aksi halde (otomatik esik, raporlayan istegi) null. */
    private static Long adminActorOrNull() {
        RequestAttributes ra = RequestContextHolder.getRequestAttributes();
        if (ra instanceof ServletRequestAttributes sra && sra.getRequest().getRequestURI().startsWith("/api/admin/")) {
            return CurrentUser.idOrNull();
        }
        return null;
    }
}
