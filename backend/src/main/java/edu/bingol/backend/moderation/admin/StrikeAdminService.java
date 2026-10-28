package edu.bingol.backend.moderation.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.ModerationNotifier;
import edu.bingol.backend.moderation.ModerationStrike;
import edu.bingol.backend.moderation.ModerationStrikeRepository;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.admin.ModAdminDtos.ForgiveResult;
import edu.bingol.backend.moderation.admin.ModAdminDtos.PageResult;
import edu.bingol.backend.moderation.admin.ModAdminDtos.StrikeRow;
import edu.bingol.backend.moderation.admin.ModAdminDtos.UserStrikes;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Ihlal (strike) listesi ve yonetici afi (P11). Sayac mantigi StrikeService ile ayni: revokedAt dolu = sayilmaz. */
@Service
public class StrikeAdminService {

    private final ModerationStrikeRepository strikes;
    private final UserRepository users;
    private final ModerationNotifier notifier;

    public StrikeAdminService(ModerationStrikeRepository strikes, UserRepository users, ModerationNotifier notifier) {
        this.strikes = strikes;
        this.users = users;
        this.notifier = notifier;
    }

    /** status: ACTIVE (sayilan) | REVOKED (iptal/af) | bos/ALL. */
    @Transactional(readOnly = true)
    public PageResult<StrikeRow> list(Long userId, ReportTargetType type, Report.Resolution resolution, String status,
                                      Instant from, Instant toExclusive, int page, int size) {
        Specification<ModerationStrike> spec = (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (userId != null) {
                ps.add(cb.equal(root.get("userId"), userId));
            }
            if (type != null) {
                ps.add(cb.equal(root.get("targetType"), type));
            }
            if (resolution != null) {
                ps.add(cb.equal(root.get("resolution"), resolution));
            }
            if ("ACTIVE".equalsIgnoreCase(status)) {
                ps.add(cb.isNull(root.get("revokedAt")));
            } else if ("REVOKED".equalsIgnoreCase(status)) {
                ps.add(cb.isNotNull(root.get("revokedAt")));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), from));
            }
            if (toExclusive != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), toExclusive));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        int s = Math.min(Math.max(size, 1), 100);
        Page<ModerationStrike> res = strikes.findAll(spec,
                PageRequest.of(Math.max(page, 0), s, Sort.by(Sort.Direction.DESC, "id")));
        return PageResult.of(rows(res.getContent()), res.getNumber(), s, res.getTotalElements());
    }

    @Transactional(readOnly = true)
    public UserStrikes ofUser(Long userId) {
        if (!users.existsById(userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        return new UserStrikes(userId, strikes.countByUserIdAndRevokedAtIsNull(userId),
                rows(strikes.findTop200ByUserIdOrderByIdDesc(userId)));
    }

    /** Af: ihlal sayilmaz (revokedAt), sebep ve af eden saklanir, kullaniciya bildirim gider. */
    @Transactional
    public ForgiveResult forgive(Long id, Long adminId, String reason) {
        ModerationStrike s = strikes.findById(id).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "STRIKE_NOT_FOUND", "İhlal kaydı bulunamadı."));
        if (s.getRevokedAt() != null) {
            throw new ApiException(HttpStatus.CONFLICT, "STRIKE_ALREADY_REVOKED", "Bu ihlal zaten sayılmıyor.");
        }
        s.setRevokedAt(Instant.now());
        s.setForgivenBy(adminId);
        s.setForgivenReason(reason == null ? null : reason.trim());
        strikes.save(s);
        AuditContext.target("STRIKE", id).reason(reason).summary("kullanıcı=" + s.getUserId() + " af");
        notifier.strikeForgiven(s.getUserId());
        return new ForgiveResult(id, s.getUserId(), strikes.countByUserIdAndRevokedAtIsNull(s.getUserId()));
    }

    private List<StrikeRow> rows(List<ModerationStrike> list) {
        Set<Long> ids = list.stream().map(ModerationStrike::getUserId).collect(Collectors.toSet());
        Map<Long, User> byId = new HashMap<>();
        if (!ids.isEmpty()) {
            users.findAllById(ids).forEach(u -> byId.put(u.getId(), u));
        }
        return list.stream().map(s -> {
            User u = byId.get(s.getUserId());
            return StrikeRow.of(s, u == null ? null : u.getDisplayName(), u == null ? null : u.getEmail());
        }).toList();
    }
}
