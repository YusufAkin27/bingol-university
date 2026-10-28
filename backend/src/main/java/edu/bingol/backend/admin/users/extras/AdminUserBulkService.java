package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkAction;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkItemResult;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkResult;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkStatus;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.moderation.UserModerationService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Toplu kullanici islemi (askiya al / geri ac / oturumlari kapat). Kismi basari raporu doner: her kimlik kendi
 * islemindedir (biri patlarsa digerleri etkilenmez). KORUMALAR: ADMIN rolundeki hesaplar ve ADMIN_EMAILS'te sabitli
 * hesaplar atlanir, yonetici kendini asla etkilemez, silinmis/yok hesaplar basarisiz sayilir.
 */
@Service
public class AdminUserBulkService {

    public static final int MAX_IDS = 100;
    /** Askı sebebi sutunu (app_user.suspended_reason) 300 karakterdir. */
    static final int MAX_REASON = 300;

    private static final Logger log = LoggerFactory.getLogger(AdminUserBulkService.class);

    private final UserRepository users;
    private final UserModerationService moderation;
    private final SessionService sessions;
    private final AdminProperties admin;

    public AdminUserBulkService(UserRepository users, UserModerationService moderation, SessionService sessions,
                                AdminProperties admin) {
        this.users = users;
        this.moderation = moderation;
        this.sessions = sessions;
        this.admin = admin;
    }

    /** Bu sinif bilerek @Transactional DEGILDIR: her kimlik, cagrilan servisin kendi islemindedir. */
    public BulkResult run(Long actorId, BulkAction action, List<Long> rawIds, String reason) {
        String r = Targets.reason(reason, AdminGuardPolicy.DEFAULT_MIN_REASON);
        if (r.length() > MAX_REASON) {
            r = r.substring(0, MAX_REASON);
        }
        LinkedHashSet<Long> ids = new LinkedHashSet<>();
        if (rawIds != null) {
            rawIds.stream().filter(x -> x != null && x > 0).forEach(ids::add);
        }
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Kullanıcı seçilmedi.");
        }
        if (ids.size() > MAX_IDS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "USER_BULK_LIMIT",
                    "Tek seferde en fazla " + MAX_IDS + " kullanıcı işlenebilir.", String.valueOf(MAX_IDS));
        }
        List<BulkItemResult> out = new ArrayList<>();
        int done = 0;
        int skipped = 0;
        int failed = 0;
        for (Long id : ids) {
            BulkItemResult res = one(actorId, action, id, r);
            out.add(res);
            switch (res.status()) {
                case DONE -> done++;
                case SKIPPED -> skipped++;
                case FAILED -> failed++;
            }
        }
        return new BulkResult(action, ids.size(), done, skipped, failed, out);
    }

    private BulkItemResult one(Long actorId, BulkAction action, Long id, String reason) {
        try {
            if (id.equals(actorId)) {
                return skip(id, "SELF");
            }
            User u = users.findById(id).orElse(null);
            if (u == null || u.getStatus() == UserStatus.DELETED) {
                return new BulkItemResult(id, BulkStatus.FAILED, "USER_NOT_FOUND");
            }
            if (u.getRole() == Role.ADMIN) {
                return skip(id, "ADMIN_TARGET");
            }
            if (admin != null && u.getEmail() != null && admin.isAdminEmail(u.getEmail())) {
                return skip(id, "ADMIN_EMAIL_PINNED");
            }
            switch (action) {
                case SUSPEND -> {
                    if (u.getStatus() == UserStatus.SUSPENDED) {
                        return skip(id, "ALREADY_SUSPENDED");
                    }
                    moderation.suspend(id, reason);
                }
                case UNSUSPEND -> {
                    if (u.getStatus() != UserStatus.SUSPENDED) {
                        return skip(id, "NOT_SUSPENDED");
                    }
                    moderation.unsuspend(id);
                }
                case REVOKE_SESSIONS -> sessions.revokeAll(id);
            }
            return new BulkItemResult(id, BulkStatus.DONE, null);
        } catch (ApiException e) {
            return new BulkItemResult(id, BulkStatus.FAILED, e.code());
        } catch (RuntimeException e) {
            log.warn("toplu kullanici islemi basarisiz action={} userId={}: {}", action, id, e.toString());
            return new BulkItemResult(id, BulkStatus.FAILED, "INTERNAL_ERROR");
        }
    }

    private static BulkItemResult skip(Long id, String code) {
        return new BulkItemResult(id, BulkStatus.SKIPPED, code);
    }
}
