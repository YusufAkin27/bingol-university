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

    public AdminUserService(AdminUserRepository repo, UserRepository users, ProfileService profiles,
                            StringRedisTemplate redis, JwtService jwt, Clock clock) {
        this.repo = repo;
        this.users = users;
        this.profiles = profiles;
        this.redis = redis;
        this.jwt = jwt;
        this.clock = clock;
    }

    public PageResponse<AdminUserRow> list(UserFilter f, String sort, int page, int size) {
        String orderBy = UserFilter.orderBy(sort);
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        return PageResponse.of(repo.page(f, orderBy, p, s), p, s, repo.count(f));
    }

    public AdminUserDetail detail(Long id) {
        return repo.detail(id).orElseThrow(AdminUserService::notFound);
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
        if (u.getRole() == Role.ADMIN) {
            requireAnotherAdmin();
        }
        u.setRole(role);
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
        if (u.getRole() == Role.ADMIN) {
            requireAnotherAdmin();
        }
        profiles.anonymizeAccount(targetId);
        // Mevcut access token'lar aninda gecersiz olsun (askiya almadaki mekanizma)
        redis.opsForValue().set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + targetId, "1");
    }

    /** Tum yonetici satirlarini kilitleyip (yaris olmasin) en az iki aktif yonetici oldugunu dogrular. */
    private void requireAnotherAdmin() {
        users.lockAdminIds();
        if (users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE) <= 1) {
            throw new ApiException(HttpStatus.CONFLICT, "LAST_ADMIN", "Son yönetici düşürülemez veya silinemez.");
        }
    }

    private void markRoleChanged(Long userId) {
        redis.opsForValue().set(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + userId,
                String.valueOf(clock.instant().getEpochSecond()), jwt.accessTtl().plus(Duration.ofMinutes(1)));
    }

    private User find(Long id) {
        return users.findById(id).filter(u -> u.getStatus() != UserStatus.DELETED).orElseThrow(AdminUserService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
    }
}
