package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AdminUserDetail;
import edu.bingol.backend.admin.AdminDtos.AdminUserRow;
import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.time.Clock;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici kullanici islemleri: liste/detay/CSV, rol degistirme, silme. */
@Service
public class AdminUserService {

    public static final int MAX_PAGE_SIZE = 100;
    public static final int CSV_MAX_ROWS = 50_000;

    private final AdminUserRepository repo;
    private final UserRepository users;
    private final ProfileService profiles;
    private final StringRedisTemplate redis;
    private final JwtService jwt;
    private final Clock clock;
    private edu.bingol.backend.auth.token.SessionService sessions;
    private edu.bingol.backend.config.AdminProperties adminProperties;
    private edu.bingol.backend.admin.rbac.AdminProfileResolver profileResolver;

    public AdminUserService(AdminUserRepository repo, UserRepository users, ProfileService profiles,
                            StringRedisTemplate redis, JwtService jwt, Clock clock) {
        this.repo = repo;
        this.users = users;
        this.profiles = profiles;
        this.redis = redis;
        this.jwt = jwt;
        this.clock = clock;
    }

    /** Oturum iptali (istege bagli: yalniz birim testlerinde yok). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSessions(edu.bingol.backend.auth.token.SessionService sessions) {
        this.sessions = sessions;
    }

    /** ADMIN_EMAILS (`app.admin.emails`) listesi: istege bagli (birim testlerinde yok). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAdminProperties(edu.bingol.backend.config.AdminProperties adminProperties) {
        this.adminProperties = adminProperties;
    }

    /** Etkin yonetici profili cozumleyici (istege bagli: yalniz birim testlerinde yok). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setProfileResolver(edu.bingol.backend.admin.rbac.AdminProfileResolver profileResolver) {
        this.profileResolver = profileResolver;
    }

    /**
     * Hedef FULL yonetici ise rol dusurme/silme iki kisi onayi ister (T-012): RBAC akisi (profil onerisi + ikinci FULL
     * onayi) once FULL'u dusurur, sonra rol/silme tek basina yapilabilir. Son FULL hicbir kosulda dusurulemez/silinemez.
     */
    private void requireNoFullTarget(User u) {
        if (profileResolver == null || u.getRole() != Role.ADMIN) {
            return;
        }
        edu.bingol.backend.admin.rbac.AdminProfile cur = profileResolver.effective(u);
        if (edu.bingol.backend.admin.rbac.RbacService.needsApproval(cur,
                edu.bingol.backend.admin.rbac.AdminProfile.VIEWER)) {
            users.lockAdminIds();
            if (users.countFullAdmins() <= 1) {
                throw new ApiException(HttpStatus.CONFLICT, "RBAC_LAST_FULL", "Son FULL yönetici düşürülemez.");
            }
            throw new ApiException(HttpStatus.CONFLICT, "RBAC_APPROVAL_REQUIRED",
                    "FULL yöneticiyi düşürmek veya birini FULL yapmak iki kişi onayı ister (öneri oluşturun).");
        }
    }

    /**
     * ADMIN_EMAILS'teki hesap panelden dusurulemez/silinemez: bir sonraki giriste `promoteIfAdmin` rolu zaten geri
     * yukseltirdi (sessiz geri alma + yaniltici denetim kaydi). Kalici cikarma icin once ADMIN_EMAILS'ten kaldirilmali.
     */
    private void requireNotPinned(User u) {
        if (adminProperties != null && u.getEmail() != null && adminProperties.isAdminEmail(u.getEmail())) {
            throw new ApiException(HttpStatus.CONFLICT, "ADMIN_EMAIL_PINNED",
                    "Bu hesap ADMIN_EMAILS listesinde; panelden düşürülemez veya silinemez.");
        }
    }

    public PageResponse<AdminUserRow> list(UserFilter f, String sort, int page, int size) {
        String orderBy = UserFilter.orderBy(sort);
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        return PageResponse.of(repo.page(f, orderBy, p, s).stream().map(AdminUserRow::masked).toList(), p, s,
                repo.count(f));
    }

    public AdminUserDetail detail(Long id) {
        return repo.detail(id).orElseThrow(AdminUserService::notFound).masked();
    }

    /** CSV: BOM + baslik + en cok 50.000 satir; satirlar bellekte biriktirilmeden yazilir. Yazilan satir sayisini doner. */
    public int writeCsv(UserFilter f, String sort, Writer out) {
        String orderBy = UserFilter.orderBy(sort);
        int[] n = {0};
        try {
            out.write(Csv.BOM);
            out.write(Csv.row(AdminUserRepository.CSV_HEADER));
            repo.stream(f, orderBy, CSV_MAX_ROWS, r -> {
                try {
                    out.write(Csv.row(AdminUserRepository.csvCells(r)));
                    n[0]++;
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
            out.flush();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return n[0];
    }

    /**
     * Rol degistirir. Kendi rolunu dusuremez (CANNOT_MODIFY_SELF); son yonetici dusurulemez (LAST_ADMIN).
     * Eski JWT'nin role claim'i 15 dk yasar: Redis isareti ile o kullanicinin eski token'lari reddedilir,
     * kullanici refresh ile yeni rolde token alir. `actorId` Basic auth yoneticisi icin null olabilir.
     */
    @Transactional
    public void changeRole(Long actorId, Long targetId, Role role) {
        if (targetId.equals(actorId) && role != Role.ADMIN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_MODIFY_SELF", "Kendi rolünüzü değiştiremezsiniz.");
        }
        User u = find(targetId);
        if (u.getRole() == role) {
            return;
        }
        if (role != Role.ADMIN) {
            requireNotPinned(u);
        }
        if (u.getRole() == Role.ADMIN) {
            requireNoFullTarget(u);
            requireAnotherAdmin();
        }
        u.setRole(role);
        // P16: yeni yonetici EN DAR profille (VIEWER) baslar; FULL yonetici sonra profil atar. Dusurulen hesapta profil silinir.
        u.setAdminProfile(role == Role.ADMIN ? edu.bingol.backend.admin.rbac.AdminProfile.VIEWER : null);
        users.save(u);
        markRoleChanged(targetId);
    }

    /** Hesabi anonimlestirir (hesap silme ile ayni mantik); kendini silemez, son yonetici silinemez. */
    @Transactional
    public void delete(Long actorId, Long targetId) {
        if (targetId.equals(actorId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_MODIFY_SELF", "Kendi hesabınızı silemezsiniz.");
        }
        User u = find(targetId);
        requireNotPinned(u);
        if (u.getRole() == Role.ADMIN) {
            requireNoFullTarget(u);
            requireAnotherAdmin();
        }
        profiles.anonymizeAccount(targetId);
        // Mevcut access token'lar aninda gecersiz olsun (askiya almadaki mekanizma)
        redis.opsForValue().set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + targetId, "1");
        // Refresh token'lar da kapansin (silinen hesabin oturum kumesi Redis'te bekleyip yasamasin).
        if (sessions != null) {
            sessions.revokeAll(targetId);
        }
    }

    /** Tum yonetici satirlarini kilitleyip (yaris olmasin) en az iki aktif yonetici oldugunu dogrular. */
    private void requireAnotherAdmin() {
        users.lockAdminIds();
        if (users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE) <= 1) {
            throw new ApiException(HttpStatus.CONFLICT, "LAST_ADMIN", "Son yönetici düşürülemez veya silinemez.");
        }
    }

    /**
     * Rol degisim isareti (ms hassasiyetinde) islem COMMIT OLDUKTAN sonra yazilir: erken yazilirsa, commit'ten once
     * refresh edilen kullanici eski rolle yeni token alir ve isaret onu rededemez. Isaret zamani commit anindan
     * alinir (yeni token'lar isaretten buyuk iatms tasir). Islem yoksa (birim testi) hemen yazilir.
     */
    private void markRoleChanged(Long userId) {
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            writeRoleMark(userId);
                        }
                    });
        } else {
            writeRoleMark(userId);
        }
    }

    private void writeRoleMark(Long userId) {
        redis.opsForValue().set(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + userId,
                String.valueOf(clock.millis()), jwt.accessTtl().plus(Duration.ofMinutes(1)));
    }

    private User find(Long id) {
        return users.findById(id).filter(u -> u.getStatus() != UserStatus.DELETED).orElseThrow(AdminUserService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
    }
}
