package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Itiraz akisi: icerigi moderasyonla (otomatik esik veya yonetici karari) gizlenen sahibi itiraz acar, yonetici karar verir.
 * Yalnizca geri alinabilir ({@link ReportTargetHandler#reversible()}) turlerde itiraz acilir.
 */
@Service
public class AppealService {

    private final ModerationAppealRepository appeals;
    private final ModerationTargetStateRepository states;
    private final ReportService reportService;
    private final StrikeService strikes;
    private final ModerationNotifier notifier;

    public AppealService(ModerationAppealRepository appeals, ModerationTargetStateRepository states,
                         ReportService reportService, StrikeService strikes, ModerationNotifier notifier) {
        this.appeals = appeals;
        this.states = states;
        this.reportService = reportService;
        this.strikes = strikes;
        this.notifier = notifier;
    }

    @Transactional
    public ModerationAppeal create(Long userId, ReportTargetType type, Long targetId, String message) {
        ReportTargetHandler h = reportService.handlerFor(type);
        // Baskasinin icerigi veya gizli olmayan icerik: varligi sizdirmamak icin ayni 404
        ModerationTargetState state = states.findByTargetTypeAndTargetId(type, targetId)
                .filter(s -> s.getHiddenBy() != null)
                .filter(s -> h.exists(targetId) && h.ownerId(targetId).filter(userId::equals).isPresent())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "APPEAL_TARGET_NOT_FOUND",
                        "İtiraz edilebilir içerik bulunamadı."));
        if (!h.reversible()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "APPEAL_NOT_ALLOWED", "Bu içerik türü için itiraz açılamaz.");
        }
        if (appeals.existsByUserIdAndTargetTypeAndTargetIdAndCreatedAtAfter(userId, type, targetId,
                state.getHiddenAt() == null ? Instant.EPOCH : state.getHiddenAt().minusSeconds(1))) {
            throw new ApiException(HttpStatus.CONFLICT, "APPEAL_ALREADY_EXISTS", "Bu içerik için zaten itiraz ettiniz.");
        }
        ModerationAppeal a = new ModerationAppeal();
        a.setUserId(userId);
        a.setTargetType(type);
        a.setTargetId(targetId);
        a.setMessage(message.trim());
        a = appeals.save(a);
        notifier.adminAppealOpened(a.getId());
        return a;
    }

    @Transactional(readOnly = true)
    public List<ModerationAppeal> mine(Long userId) {
        return appeals.findTop50ByUserIdOrderByIdDesc(userId);
    }

    @Transactional(readOnly = true)
    public List<ModerationAppeal> page(ModerationAppeal.Status status, Long cursor, int size) {
        return appeals.page(status, cursor, PageRequest.of(0, size + 1));
    }

    @Transactional
    public void decide(Long id, Long adminId, boolean accept, String note) {
        ModerationAppeal a = appeals.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "APPEAL_NOT_FOUND", "İtiraz bulunamadı."));
        if (a.getStatus() != ModerationAppeal.Status.OPEN) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_RESOLVED", "Kayıt zaten sonuçlandırılmış.");
        }
        if (accept) {
            ReportTargetHandler h = reportService.handlerFor(a.getTargetType());
            if (!h.reversible()) {
                throw new ApiException(HttpStatus.CONFLICT, "TARGET_NOT_REVERSIBLE", "Bu içerik geri açılamıyor.");
            }
            Optional<ModerationTargetState> st = states.findByTargetTypeAndTargetId(a.getTargetType(), a.getTargetId());
            if (h.exists(a.getTargetId())) {
                h.unhide(a.getTargetId());
            }
            st.ifPresent(s -> states.clear(a.getTargetType(), a.getTargetId()));
            strikes.revokeForTarget(a.getTargetType(), a.getTargetId());
        }
        a.setStatus(accept ? ModerationAppeal.Status.ACCEPTED : ModerationAppeal.Status.REJECTED);
        a.setAdminNote(note == null || note.isBlank() ? null : note.trim());
        a.setDecidedBy(adminId);
        a.setDecidedAt(Instant.now());
        notifier.appealDecided(a.getUserId(), accept, a.getAdminNote());
    }
}
