package edu.bingol.backend.admin.rbac;

import edu.bingol.backend.admin.rbac.RbacDtos.AdminRow;
import edu.bingol.backend.admin.rbac.RbacDtos.ChangeView;
import edu.bingol.backend.admin.rbac.RbacDtos.Matrix;
import edu.bingol.backend.admin.rbac.RbacDtos.MatrixEntry;
import edu.bingol.backend.admin.rbac.RbacDtos.Me;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici profili yonetimi (P16). KURALLAR: kendi profilini degistiremez; ADMIN_EMAILS'te sabitli hesap degistirilemez;
 * son FULL yonetici dusurulemez; FULL yoneticiyi dusurmek ya da birini FULL yapmak IKI KISI ONAYI ister (oneren onaylayamaz,
 * 24 saat gecerli); diger degisiklikler dogrudan yapilir. Profil degisince hedefin eski token'lari `rolechg:<id>`
 * isaretiyle reddedilir (refresh ile yeni profilde token alir).
 */
@Service
public class RbacService {

    public static final Duration CHANGE_TTL = Duration.ofHours(24);

    private final UserRepository users;
    private final AdminProfileChangeRepository changes;
    private final AdminProfileResolver resolver;
    private final StringRedisTemplate redis;
    private final JwtService jwt;
    private final Clock clock;

    public RbacService(UserRepository users, AdminProfileChangeRepository changes, AdminProfileResolver resolver,
                       StringRedisTemplate redis, JwtService jwt, Clock clock) {
        this.users = users;
        this.changes = changes;
        this.resolver = resolver;
        this.redis = redis;
        this.jwt = jwt;
        this.clock = clock;
    }

    // --- okuma ---

    public Me me() {
        AdminPermissionContext ctx = AdminPermissionContext.current();
        AdminProfile profile = ctx == null ? AdminProfile.FULL : ctx.profile();
        boolean pinned = ctx != null && ctx.pinned();
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        Long id = a != null && a.getPrincipal() instanceof Long l ? l : null;
        User u = id == null ? null : users.findById(id).orElse(null);
        return new Me(id, u == null ? null : u.getEmail(), u == null ? null : u.getDisplayName(), profile, pinned,
                List.copyOf(PermissionMatrix.permissionsOf(profile)));
    }

    public Matrix matrix() {
        List<MatrixEntry> entries = PermissionMatrix.grants().entrySet().stream()
                .map(e -> new MatrixEntry(e.getKey(), e.getValue())).toList();
        return new Matrix(PermissionMatrix.profiles(), entries);
    }

    @Transactional(readOnly = true)
    public List<AdminRow> admins() {
        return users.findAllAdmins().stream().map(u -> new AdminRow(u.getId(), u.getEmail(), u.getDisplayName(),
                resolver.effective(u), resolver.isPinned(u.getEmail()), u.getStatus().name(),
                u.getLastSeenAt() == null ? null : u.getLastSeenAt().toString())).toList();
    }

    @Transactional
    public List<ChangeView> changes(AdminProfileChange.Status status) {
        changes.expireOverdue(clock.instant());
        List<AdminProfileChange> rows = status == null ? changes.findTop100ByOrderByIdDesc()
                : changes.findTop100ByStatusOrderByIdDesc(status);
        Set<Long> ids = new HashSet<>();
        for (AdminProfileChange c : rows) {
            ids.add(c.getTargetUserId());
            ids.add(c.getProposedBy());
        }
        Map<Long, User> byId = new HashMap<>();
        users.findAllById(ids).forEach(u -> byId.put(u.getId(), u));
        return rows.stream().map(c -> view(c, byId)).toList();
    }

    // --- yazma ---

    /** Dogrudan profil atama (FULL'i ilgilendirmeyen degisiklikler). */
    @Transactional
    public AdminProfile setProfile(Long actorId, Long targetId, AdminProfile to) {
        User t = check(actorId, targetId, to);
        AdminProfile cur = resolver.effective(t);
        if (needsApproval(cur, to)) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_APPROVAL_REQUIRED",
                    "FULL yöneticiyi düşürmek veya birini FULL yapmak iki kişi onayı ister (öneri oluşturun).");
        }
        apply(t, to);
        return cur;
    }

    @Transactional
    public ChangeView propose(Long actorId, Long targetId, AdminProfile to, String reason) {
        User t = check(actorId, targetId, to);
        AdminProfile cur = resolver.effective(t);
        if (!needsApproval(cur, to)) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_APPROVAL_NOT_NEEDED",
                    "Bu değişiklik onay istemez; doğrudan uygulayın.");
        }
        if (changes.existsByTargetUserIdAndStatus(targetId, AdminProfileChange.Status.PENDING)) {
            // Suresi dolmus bekleyen kayit yeni oneriyi engellemesin
            changes.expireOverdue(clock.instant());
            if (changes.existsByTargetUserIdAndStatus(targetId, AdminProfileChange.Status.PENDING)) {
                throw new ApiException(HttpStatus.CONFLICT, "RBAC_CHANGE_PENDING",
                        "Bu yönetici için bekleyen bir değişiklik önerisi var.");
            }
        }
        Instant now = clock.instant();
        AdminProfileChange c = new AdminProfileChange();
        c.setTargetUserId(targetId);
        c.setFromProfile(cur);
        c.setToProfile(to);
        c.setReason(reason.strip());
        c.setProposedBy(actorId);
        c.setProposedAt(now);
        c.setExpiresAt(now.plus(CHANGE_TTL));
        c = changes.save(c);
        return view(c, mapOf(t, users.findById(actorId).orElse(null)));
    }

    /** Ikinci FULL yonetici onaylar; sure dolmussa durum EXPIRED olarak KALIR (geri alinmaz). */
    @Transactional(noRollbackFor = ApiException.class)
    public ChangeView approve(Long actorId, Long changeId, String note) {
        AdminProfileChange c = changes.findForUpdate(changeId).orElseThrow(RbacService::changeNotFound);
        requirePending(c);
        Instant now = clock.instant();
        if (c.getExpiresAt().isBefore(now)) {
            c.setStatus(AdminProfileChange.Status.EXPIRED);
            changes.save(c);
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_CHANGE_EXPIRED", "Önerinin süresi dolmuş (24 saat).");
        }
        if (c.getProposedBy().equals(actorId)) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_SAME_APPROVER",
                    "Öneriyi yapan kişi onaylayamaz; ikinci bir FULL yönetici gerekir.");
        }
        User t = users.findById(c.getTargetUserId()).orElse(null);
        if (t != null && resolver.effective(t) != c.getFromProfile()) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_CHANGE_STALE",
                    "Hedefin profili öneriden sonra değişmiş; yeni öneri oluşturun.");
        }
        t = check(actorId, c.getTargetUserId(), c.getToProfile());
        apply(t, c.getToProfile());
        c.setStatus(AdminProfileChange.Status.APPROVED);
        c.setDecidedBy(actorId);
        c.setDecidedAt(now);
        c.setDecisionNote(clip(note));
        changes.save(c);
        return view(c, mapOf(t, users.findById(c.getProposedBy()).orElse(null)));
    }

    /** Ret ya da geri cekme (oneren de reddedebilir). */
    @Transactional
    public ChangeView reject(Long actorId, Long changeId, String note) {
        AdminProfileChange c = changes.findForUpdate(changeId).orElseThrow(RbacService::changeNotFound);
        requirePending(c);
        c.setStatus(AdminProfileChange.Status.REJECTED);
        c.setDecidedBy(actorId);
        c.setDecidedAt(clock.instant());
        c.setDecisionNote(clip(note));
        changes.save(c);
        return view(c, mapOf(users.findById(c.getTargetUserId()).orElse(null),
                users.findById(c.getProposedBy()).orElse(null)));
    }

    // --- ic yardimcilar ---

    /** FULL'i dusurmek ya da FULL yapmak iki kisi onayi ister. */
    static boolean needsApproval(AdminProfile current, AdminProfile to) {
        return current == AdminProfile.FULL || to == AdminProfile.FULL;
    }

    /** Ortak dogrulamalar; hedef kullaniciyi doner. */
    private User check(Long actorId, Long targetId, AdminProfile to) {
        if (actorId == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Giriş gerekli.");
        }
        if (targetId.equals(actorId)) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_SELF_CHANGE", "Kendi profilinizi değiştiremezsiniz.");
        }
        User t = users.findById(targetId).filter(u -> u.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        if (t.getRole() != Role.ADMIN) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_TARGET_NOT_ADMIN", "Hedef hesap yönetici değil.");
        }
        if (resolver.isPinned(t.getEmail())) {
            throw new ApiException(HttpStatus.CONFLICT, "ADMIN_EMAIL_PINNED",
                    "Bu hesap ADMIN_EMAILS listesinde; panelden düşürülemez veya silinemez.");
        }
        AdminProfile cur = resolver.effective(t);
        if (cur == to) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_NO_CHANGE", "Yönetici zaten bu profilde.");
        }
        if (cur == AdminProfile.FULL) {
            users.lockAdminIds(); // yarisi onle: iki es zamanli dusurme son FULL'u silmesin
            if (users.countFullAdmins() <= 1) {
                throw new ApiException(HttpStatus.CONFLICT, "RBAC_LAST_FULL", "Son FULL yönetici düşürülemez.");
            }
        }
        return t;
    }

    private void apply(User t, AdminProfile to) {
        t.setAdminProfile(to);
        users.save(t);
        markChanged(t.getId());
    }

    private static void requirePending(AdminProfileChange c) {
        if (c.getStatus() != AdminProfileChange.Status.PENDING) {
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_CHANGE_DECIDED", "Bu öneri zaten sonuçlanmış.");
        }
    }

    private static ApiException changeNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "RBAC_CHANGE_NOT_FOUND", "Değişiklik önerisi bulunamadı.");
    }

    private static String clip(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String v = s.strip();
        return v.length() > 300 ? v.substring(0, 300) : v;
    }

    private static Map<Long, User> mapOf(User... us) {
        Map<Long, User> m = new HashMap<>();
        for (User u : us) {
            if (u != null) {
                m.put(u.getId(), u);
            }
        }
        return m;
    }

    private ChangeView view(AdminProfileChange c, Map<Long, User> byId) {
        User t = byId.get(c.getTargetUserId());
        User p = byId.get(c.getProposedBy());
        return new ChangeView(c.getId(), c.getTargetUserId(), t == null ? null : t.getEmail(),
                t == null ? null : t.getDisplayName(), c.getFromProfile(), c.getToProfile(), c.getReason(),
                c.getProposedBy(), p == null ? null : p.getEmail(), c.getProposedAt().toString(),
                c.getExpiresAt().toString(), c.getStatus().name(), c.getDecidedBy(),
                c.getDecidedAt() == null ? null : c.getDecidedAt().toString(), c.getDecisionNote());
    }

    /** Isaret islem COMMIT OLDUKTAN sonra yazilir (bkz. AdminUserService.markRoleChanged ile ayni gerekce). */
    private void markChanged(Long userId) {
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            writeMark(userId);
                        }
                    });
        } else {
            writeMark(userId);
        }
    }

    private void writeMark(Long userId) {
        redis.opsForValue().set(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + userId, String.valueOf(clock.millis()),
                jwt.accessTtl().plus(Duration.ofMinutes(1)));
    }
}
