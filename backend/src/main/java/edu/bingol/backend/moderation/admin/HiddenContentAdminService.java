package edu.bingol.backend.moderation.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ModerationNotifier;
import edu.bingol.backend.moderation.ModerationTargetState;
import edu.bingol.backend.moderation.ModerationTargetStateRepository;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.StrikeService;
import edu.bingol.backend.moderation.admin.ModAdminDtos.HiddenRow;
import edu.bingol.backend.moderation.admin.ModAdminDtos.PageResult;
import edu.bingol.backend.moderation.admin.ModAdminDtos.RestoreResult;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyonla gizlenen iceriklerin birlesik listesi ve yonetici geri almasi (P11). Geri alma yalniz
 * {@link ReportTargetHandler#reversible()} turlerde; geri alinamayan tur 409 TARGET_NOT_REVERSIBLE.
 */
@Service
public class HiddenContentAdminService {

    private static final Logger log = LoggerFactory.getLogger(HiddenContentAdminService.class);

    private final ModerationTargetStateRepository states;
    private final Map<ReportTargetType, ReportTargetHandler> handlers = new EnumMap<>(ReportTargetType.class);
    private final StrikeService strikes;
    private final ModerationNotifier notifier;
    private final UserRepository users;

    public HiddenContentAdminService(ModerationTargetStateRepository states, List<ReportTargetHandler> handlerBeans,
                                     StrikeService strikes, ModerationNotifier notifier, UserRepository users) {
        this.states = states;
        this.strikes = strikes;
        this.notifier = notifier;
        this.users = users;
        handlerBeans.forEach(h -> handlers.put(h.type(), h));
    }

    @Transactional(readOnly = true)
    public PageResult<HiddenRow> list(ReportTargetType type, ModerationTargetState.HiddenBy hiddenBy, Instant from,
                                      Instant toExclusive, int page, int size) {
        Specification<ModerationTargetState> spec = (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            ps.add(cb.isNotNull(root.get("hiddenBy")));
            if (type != null) {
                ps.add(cb.equal(root.get("targetType"), type));
            }
            if (hiddenBy != null) {
                ps.add(cb.equal(root.get("hiddenBy"), hiddenBy));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("hiddenAt"), from));
            }
            if (toExclusive != null) {
                ps.add(cb.lessThan(root.<Instant>get("hiddenAt"), toExclusive));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        int s = Math.min(Math.max(size, 1), 100);
        Page<ModerationTargetState> res = states.findAll(spec, PageRequest.of(Math.max(page, 0), s,
                Sort.by(Sort.Order.desc("hiddenAt"), Sort.Order.desc("id"))));
        List<HiddenRow> rows = new ArrayList<>();
        Set<Long> ownerIds = new HashSet<>();
        for (ModerationTargetState st : res.getContent()) {
            ReportTargetHandler h = handlers.get(st.getTargetType());
            boolean exists = false;
            boolean reversible = false;
            Long owner = null;
            MediaPreview preview = null;
            if (h != null) {
                try {
                    reversible = h.reversible();
                    exists = h.exists(st.getTargetId());
                    if (exists) {
                        owner = h.ownerId(st.getTargetId()).orElse(null);
                        preview = h.preview(st.getTargetId()).orElse(null);
                    }
                } catch (RuntimeException e) {
                    log.warn("Gizli icerik ayrintisi alinamadi {} #{}: {}", st.getTargetType(), st.getTargetId(), e.toString());
                }
            }
            if (owner != null) {
                ownerIds.add(owner);
            }
            rows.add(new HiddenRow(st.getTargetType(), st.getTargetId(), st.getHiddenBy(),
                    st.getHiddenAt() == null ? null : st.getHiddenAt().toString(), reversible, exists, owner, null, preview));
        }
        Map<Long, User> byId = new HashMap<>();
        if (!ownerIds.isEmpty()) {
            users.findAllById(ownerIds).forEach(u -> byId.put(u.getId(), u));
        }
        List<HiddenRow> named = rows.stream().map(r -> {
            User u = r.ownerId() == null ? null : byId.get(r.ownerId());
            return u == null ? r : new HiddenRow(r.targetType(), r.targetId(), r.hiddenBy(), r.hiddenAt(), r.reversible(),
                    r.exists(), r.ownerId(), u.getDisplayName(), r.preview());
        }).toList();
        return PageResult.of(named, res.getNumber(), s, res.getTotalElements());
    }

    /** Geri al: icerik yeniden gorunur, gizleme isareti silinir, hedefe bagli ihlaller sayilmaz, sahibine bildirim gider. */
    @Transactional
    public RestoreResult restore(ReportTargetType type, Long targetId, String reason) {
        ModerationTargetState st = states.findByTargetTypeAndTargetId(type, targetId)
                .filter(s -> s.getHiddenBy() != null)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "HIDDEN_CONTENT_NOT_FOUND",
                        "Gizlenmiş içerik bulunamadı."));
        ReportTargetHandler h = handlers.get(type);
        if (h == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TARGET_TYPE_UNSUPPORTED", "Bu tür henüz raporlanamıyor.");
        }
        if (!h.reversible()) {
            throw new ApiException(HttpStatus.CONFLICT, "TARGET_NOT_REVERSIBLE", "Bu içerik geri açılamıyor.");
        }
        boolean exists = h.exists(targetId);
        Optional<Long> owner = exists ? h.ownerId(targetId) : Optional.empty();
        if (exists) {
            h.unhide(targetId);
        }
        states.clear(st.getTargetType(), st.getTargetId());
        strikes.revokeForTarget(type, targetId);
        owner.ifPresent(uid -> notifier.restored(uid, type, targetId));
        AuditContext.target("HIDDEN_CONTENT", type.name() + ":" + targetId).reason(reason)
                .summary("geri alındı " + type + " #" + targetId);
        return new RestoreResult(type, targetId, exists);
    }
}
