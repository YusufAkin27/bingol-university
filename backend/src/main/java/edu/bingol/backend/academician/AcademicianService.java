package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianApprovalPolicy.Decision;
import edu.bingol.backend.academician.AcademicianDtos.AdminAcademicianView;
import edu.bingol.backend.academician.AcademicianDtos.ApplyRequest;
import edu.bingol.backend.academician.AcademicianDtos.MeView;
import edu.bingol.backend.academician.AcademicianDtos.StatusView;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/** Akademisyen basvurusu, kendi profili ve yonetici karari (onay/ret/iptal). Servis katmani: HTTP bilmez. */
@Service
public class AcademicianService {

    private final AcademicianRepository academicians;
    private final UserRepository users;
    private final AcademicianProperties props;
    private final AcademicianNotifier notifier;
    private final TransactionTemplate tx;
    private final org.springframework.jdbc.core.JdbcTemplate jdbc;
    private final NoticeFileService noticeFiles;
    private final AcSessionRepository sessionRepo;

    public AcademicianService(AcademicianRepository academicians, UserRepository users, AcademicianProperties props,
                              AcademicianNotifier notifier, PlatformTransactionManager tm,
                              org.springframework.jdbc.core.JdbcTemplate jdbc, NoticeFileService noticeFiles,
                              AcSessionRepository sessionRepo) {
        this.jdbc = jdbc;
        this.noticeFiles = noticeFiles;
        this.sessionRepo = sessionRepo;
        this.academicians = academicians;
        this.users = users;
        this.props = props;
        this.notifier = notifier;
        this.tx = new TransactionTemplate(tm);
    }

    // ---- akademisyenin kendisi ----

    @Transactional(readOnly = true)
    public MeView me(Long userId) {
        AcademicianDtos.Limits limits = new AcademicianDtos.Limits(noticeFiles.maxFileBytes(), NoticeFileService.MAX_FILES);
        return academicians.findById(userId).map(a -> meView(a, limits))
                .orElse(new MeView("NONE", null, null, null, null, null, null, limits));
    }

    /**
     * Basvuru. Bekleyen/onayli basvuru tekrar gelirse idempotent (mevcut durum doner); reddedilen yeniden degerlendirilir;
     * iptal edilen (REVOKED) yeniden basvuramaz. Es zamanli iki basvuru birincil anahtarla tekillenir.
     */
    public StatusView apply(Long userId, ApplyRequest r) {
        Academician existing = academicians.findById(userId).orElse(null);
        if (existing != null) {
            return switch (existing.getStatus()) {
                case PENDING, APPROVED -> new StatusView(existing.getStatus().name());
                case REVOKED -> throw new ApiException(HttpStatus.FORBIDDEN, "ACADEMICIAN_REVOKED",
                        "Akademisyen yetkiniz kaldırıldı.");
                case REJECTED -> reapply(existing, r);
            };
        }
        User u = users.findById(userId).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        Decision d = AcademicianApprovalPolicy.decide(props.autoApprove(), u);
        Academician a = new Academician();
        a.setUserId(userId);
        fill(a, r);
        a.setStatus(d.status());
        a.setApprovalMode(d.mode());
        if (d.mode() == Academician.ApprovalMode.AUTO) {
            a.setReviewedAt(Instant.now());
        }
        try {
            tx.executeWithoutResult(s -> academicians.saveAndFlush(a));
        } catch (DataIntegrityViolationException e) {
            // es zamanli ikinci basvuru: kazanan satirin durumu doner
            return academicians.findById(userId).map(x -> new StatusView(x.getStatus().name())).orElseThrow(() -> e);
        }
        if (d.status() == Academician.Status.APPROVED) {
            notifier.autoApproved(a.fullName());
        }
        return new StatusView(a.getStatus().name());
    }

    private StatusView reapply(Academician a, ApplyRequest r) {
        // Reddedilen hesap tekrar basvurunca otomatik onaya DUSMEZ: ret bir insan kararidir.
        tx.executeWithoutResult(s -> {
            Academician x = academicians.lockById(a.getUserId()).orElseThrow();
            fill(x, r);
            x.setStatus(Academician.Status.PENDING);
            x.setApprovalMode(null);
            x.setRejectReason(null);
            x.setReviewedBy(null);
            x.setReviewedAt(null);
            x.setUpdatedAt(Instant.now());
            academicians.save(x);
        });
        return new StatusView(Academician.Status.PENDING.name());
    }

    @Transactional
    public MeView updateProfile(Long userId, ApplyRequest r) {
        Academician a = academicians.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ACADEMICIAN_NOT_FOUND", "Akademisyen kaydı bulunamadı."));
        if (a.getStatus() == Academician.Status.REVOKED) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACADEMICIAN_REVOKED", "Akademisyen yetkiniz kaldırıldı.");
        }
        fill(a, r);
        a.setUpdatedAt(Instant.now());
        return meView(academicians.save(a), new AcademicianDtos.Limits(noticeFiles.maxFileBytes(), NoticeFileService.MAX_FILES));
    }

    private static void fill(Academician a, ApplyRequest r) {
        a.setTitle(clean(r.title(), "title", 40, true));
        a.setFirstName(clean(r.firstName(), "firstName", 60, true));
        a.setLastName(clean(r.lastName(), "lastName", 60, true));
        a.setUnit(clean(r.unit(), "unit", 160, false));
    }

    static String clean(String v, String field, int max, boolean required) {
        String s = v == null ? "" : v.trim().replaceAll("\\s+", " ");
        if (s.isEmpty()) {
            if (required) {
                throw AcErrors.invalid(field);
            }
            return null;
        }
        if (s.length() > max) {
            throw AcErrors.invalid(field);
        }
        return s;
    }

    private static MeView meView(Academician a, AcademicianDtos.Limits limits) {
        return new MeView(a.getStatus().name(), a.getApprovalMode() == null ? null : a.getApprovalMode().name(), a.getTitle(),
                a.getFirstName(), a.getLastName(), a.getUnit(), a.getRejectReason(), limits);
    }

    // ---- yonetici ----

    /** users.pii olmayan profillerde q icin en az uzunluk (admin kullanici aramasiyla ayni kural). */
    static final int MASKED_Q_MIN = 3;
    static final int Q_MAX = 100;

    /**
     * Yonetici listesi. {@code q} (istege bagli): ad, soyad ve gorunen ad icinde buyuk/kucuk harf duyarsiz kismi eslesme;
     * YALNIZ users.pii iznine sahip yoneticide e-posta da aranir. Maskeli profil (SUPPORT, VIEWER) e-posta ile arayarak
     * maskeli adresi yeniden kuramaz (admin kullanici aramasiyla ayni T-019 kurali): onlarda e-posta aranmaz ve en az 3
     * karakter gerekir. Imec ve sayfalama aynidir.
     */
    @Transactional(readOnly = true)
    public CursorPage<AdminAcademicianView> list(Set<Academician.Status> statuses, Academician.ApprovalMode mode, String q,
                                                 Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        Long before = cursor == null ? Long.MAX_VALUE : cursor;
        Set<Academician.Status> st = statuses == null || statuses.isEmpty() ? EnumSet.allOf(Academician.Status.class) : statuses;
        List<Academician> rows;
        String needle = q == null ? "" : q.trim();
        if (needle.isEmpty()) {
            rows = mode == null ? academicians.page(st, before, PageRequest.of(0, s + 1))
                    : academicians.pageByMode(st, mode, before, PageRequest.of(0, s + 1));
        } else {
            rows = search(st, mode, needle, before, s + 1);
        }
        boolean more = rows.size() > s;
        List<Academician> page = more ? rows.subList(0, s) : rows;
        Map<Long, User> byId = usersOf(page);
        return new CursorPage<>(page.stream().map(a -> adminView(a, byId.get(a.getUserId()))).toList(),
                more ? page.get(page.size() - 1).getUserId() : null);
    }

    private List<Academician> search(Set<Academician.Status> st, Academician.ApprovalMode mode, String needle, Long before,
                                     int limit) {
        boolean pii = PermissionAwareMasking.canSeePii();
        if (needle.length() > Q_MAX || (!pii && needle.length() < MASKED_Q_MIN)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "Arama için " + MASKED_Q_MIN + "-" + Q_MAX + " karakter girin.");
        }
        String like = "%" + needle.toLowerCase(java.util.Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        StringBuilder sql = new StringBuilder("SELECT a.user_id FROM academician a WHERE a.user_id < ? AND a.status IN (");
        List<Object> args = new java.util.ArrayList<>();
        args.add(before);
        sql.append(String.join(",", java.util.Collections.nCopies(st.size(), "?"))).append(")");
        st.forEach(x -> args.add(x.name()));
        if (mode != null) {
            sql.append(" AND a.approval_mode = ?");
            args.add(mode.name());
        }
        sql.append(" AND (lower(a.first_name) LIKE ? ESCAPE '\\' OR lower(a.last_name) LIKE ? ESCAPE '\\' "
                + "OR lower(a.first_name || ' ' || a.last_name) LIKE ? ESCAPE '\\' "
                + "OR EXISTS (SELECT 1 FROM app_user u WHERE u.id = a.user_id AND (lower(u.display_name) LIKE ? ESCAPE '\\'");
        for (int i = 0; i < 4; i++) {
            args.add(like);
        }
        if (pii) {
            sql.append(" OR lower(u.email) LIKE ? ESCAPE '\\'");
            args.add(like);
        }
        sql.append("))) ORDER BY a.user_id DESC LIMIT ?");
        args.add(limit);
        List<Long> ids = jdbc.queryForList(sql.toString(), Long.class, args.toArray());
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, Academician> byId = academicians.findAllById(ids).stream().collect(Collectors.toMap(Academician::getUserId, a -> a));
        return ids.stream().map(byId::get).filter(java.util.Objects::nonNull).toList();
    }

    @Transactional(readOnly = true)
    public AdminAcademicianView detail(Long userId) {
        Academician a = academicians.findById(userId).orElseThrow(AcademicianService::adminNotFound);
        return adminView(a, users.findById(userId).orElse(null));
    }

    /** Onay: bekleyen, reddedilen ya da iptal edilen basvuru APPROVED/ADMIN olur. */
    public AdminAcademicianView approve(Long adminId, Long userId) {
        AdminAcademicianView v = decide(adminId, userId, EnumSet.of(Academician.Status.PENDING, Academician.Status.REJECTED,
                Academician.Status.REVOKED), Academician.Status.APPROVED, null);
        notifier.decided(userId, AcademicianNotifier.Decision.APPROVED, null);
        return v;
    }

    /** Ret: yalniz bekleyen basvuru; gerekce zorunlu. */
    public AdminAcademicianView reject(Long adminId, Long userId, String reason) {
        String why = clean(reason, "reason", 300, true);
        AdminAcademicianView v = decide(adminId, userId, EnumSet.of(Academician.Status.PENDING), Academician.Status.REJECTED, why);
        notifier.decided(userId, AcademicianNotifier.Decision.REJECTED, why);
        return v;
    }

    /** Yetki iptali: yalniz onayli akademisyen; gerekce zorunlu. Dersler ve kayitlar silinmez (yeniden onayda geri gelir). */
    public AdminAcademicianView revoke(Long adminId, Long userId, String reason) {
        String why = clean(reason, "reason", 300, true);
        AdminAcademicianView v = decide(adminId, userId, EnumSet.of(Academician.Status.APPROVED), Academician.Status.REVOKED, why);
        closeLiveSessionsOf(userId); // iptal edilenin acik yoklamalari hemen kapanir
        notifier.decided(userId, AcademicianNotifier.Decision.REVOKED, why);
        return v;
    }

    /** Yetkisi alinan akademisyenin hala acik oturumlarini kapatir (tarama ayrica sahibin onayini sinar). */
    private void closeLiveSessionsOf(Long ownerId) {
        for (Long sid : sessionRepo.openIdsOfOwner(ownerId, PageRequest.of(0, 200))) {
            tx.executeWithoutResult(s -> sessionRepo.closeIfOpen(sid, Instant.now()));
        }
    }

    private AdminAcademicianView decide(Long adminId, Long userId, Set<Academician.Status> allowedFrom, Academician.Status to,
                                        String reason) {
        return tx.execute(s -> {
            Academician a = academicians.lockById(userId).orElseThrow(AcademicianService::adminNotFound);
            if (!allowedFrom.contains(a.getStatus())) {
                throw new ApiException(HttpStatus.CONFLICT, "ACADEMICIAN_BAD_STATE", "Başvuru bu durumda bu işleme uygun değil.");
            }
            a.setStatus(to);
            a.setApprovalMode(to == Academician.Status.APPROVED ? Academician.ApprovalMode.ADMIN : a.getApprovalMode());
            a.setRejectReason(to == Academician.Status.APPROVED ? null : reason);
            a.setReviewedBy(adminId);
            a.setReviewedAt(Instant.now());
            a.setUpdatedAt(Instant.now());
            academicians.save(a);
            return adminView(a, users.findById(userId).orElse(null));
        });
    }

    private Map<Long, User> usersOf(List<Academician> rows) {
        if (rows.isEmpty()) {
            return Map.of();
        }
        return users.findAllById(rows.stream().map(Academician::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, u -> u));
    }

    private static AdminAcademicianView adminView(Academician a, User u) {
        return new AdminAcademicianView(a.getUserId(), u == null ? null : PermissionAwareMasking.email(u.getEmail()),
                u == null ? null : u.getDisplayName(), a.getTitle(), a.getFirstName(), a.getLastName(), a.getUnit(),
                a.getStatus().name(), a.getApprovalMode() == null ? null : a.getApprovalMode().name(), a.getRejectReason(),
                a.getReviewedBy(), a.getReviewedAt(), a.getCreatedAt());
    }

    private static ApiException adminNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "ACADEMICIAN_NOT_FOUND", "Akademisyen kaydı bulunamadı.");
    }
}
