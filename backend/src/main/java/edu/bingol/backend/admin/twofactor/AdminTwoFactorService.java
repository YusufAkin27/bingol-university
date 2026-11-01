package edu.bingol.backend.admin.twofactor;

import edu.bingol.backend.admin.AdminHierarchy;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.admin.twofactor.AdminTwoFactorDtos.Summary;
import edu.bingol.backend.admin.twofactor.AdminTwoFactorDtos.UserPage;
import edu.bingol.backend.admin.twofactor.AdminTwoFactorDtos.UserRow;
import edu.bingol.backend.auth.twofactor.TwoFactorService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Yonetici 2FA gorunumu ve hesap kurtarma kapatmasi. Ozet/liste parametreli JDBC (PostgreSQL; H2'de de calisan
 * duz SQL). Listede `q` icin UserFilter kurallari aynen gecerli (users.pii olmayan profil yalniz gorunen ad arar,
 * kisa sorgu reddedilir). Mesaj/icerik gibi kisisel veri DONMEZ.
 */
@Service
public class AdminTwoFactorService {

    private static final Logger log = LoggerFactory.getLogger(AdminTwoFactorService.class);
    public static final int MAX_PAGE_SIZE = 100;

    private final NamedParameterJdbcTemplate jdbc;
    private final UserRepository users;
    private final TwoFactorService twoFactor;
    private final NotificationService notifications;
    private final Clock clock;

    public AdminTwoFactorService(NamedParameterJdbcTemplate jdbc, UserRepository users, TwoFactorService twoFactor,
                                 NotificationService notifications, Clock clock) {
        this.jdbc = jdbc;
        this.users = users;
        this.twoFactor = twoFactor;
        this.notifications = notifications;
        this.clock = clock;
    }

    public Summary summary() {
        MapSqlParameterSource p = new MapSqlParameterSource("since",
                OffsetDateTime.ofInstant(clock.instant().minus(7, ChronoUnit.DAYS), java.time.ZoneOffset.UTC));
        long enabled = count("SELECT count(*) FROM app_user WHERE two_factor_enabled AND status <> 'DELETED'", p);
        long active = count("SELECT count(*) FROM app_user WHERE status = 'ACTIVE'", p);
        long recent = count("SELECT count(*) FROM app_user WHERE two_factor_enabled AND two_factor_enabled_at >= :since", p);
        long devices = count("SELECT count(*) FROM two_factor_device", p);
        double pct = active == 0 ? 0.0 : Math.round(enabled * 1000.0 / active) / 10.0;
        return new Summary(enabled, active, pct, recent, devices);
    }

    public UserPage users(String q, int page, int size) {
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        UserFilter.Where w = new UserFilter(q, null, null, null, null, null, null, null, null, null, null, null, true)
                .where();
        String where = w.sql() + " AND status <> 'DELETED'";
        Long total = jdbc.queryForObject("SELECT count(*) FROM app_user WHERE " + where, w.params(), Long.class);
        long totalElements = total == null ? 0 : total;
        w.params().addValue("lim", s).addValue("off", (long) p * s);
        List<UserRow> rows = jdbc.query("SELECT id, display_name, email, role, two_factor_enabled_at, last_seen_at, "
                + "(SELECT count(*) FROM two_factor_device d WHERE d.user_id = app_user.id) AS devices, "
                + "(SELECT max(d.last_used_at) FROM two_factor_device d WHERE d.user_id = app_user.id) AS last_used "
                + "FROM app_user WHERE " + where
                + " ORDER BY two_factor_enabled_at DESC NULLS LAST, id DESC LIMIT :lim OFFSET :off",
                w.params(), (rs, i) -> row(rs));
        int totalPages = (int) ((totalElements + s - 1) / s);
        return new UserPage(rows, totalElements, totalPages, p, s);
    }

    private static UserRow row(ResultSet rs) throws SQLException {
        String email = rs.getString("email");
        OffsetDateTime used = rs.getObject("last_used", OffsetDateTime.class);
        OffsetDateTime seen = rs.getObject("last_seen_at", OffsetDateTime.class);
        OffsetDateTime enabledAt = rs.getObject("two_factor_enabled_at", OffsetDateTime.class);
        OffsetDateTime last = used != null ? used : seen;
        return new UserRow(rs.getLong("id"), rs.getString("display_name"),
                PermissionAwareMasking.canSeePii() ? email : PermissionAwareMasking.maskEmail(email),
                rs.getString("role"), enabledAt == null ? null : enabledAt.toInstant().toString(),
                rs.getLong("devices"), last == null ? null : last.toInstant().toString());
    }

    private long count(String sql, MapSqlParameterSource p) {
        Long n = jdbc.queryForObject(sql, p, Long.class);
        return n == null ? 0 : n;
    }

    /**
     * Hesap kurtarma: 2FA'yi kapatir, guvenilen cihazlari siler, kullaniciya bildirim gonderir. Yonetici hesabina
     * yalniz FULL mudahale eder (AdminHierarchy). Zaten kapaliysa 409 TWO_FACTOR_NOT_ENABLED. Denetim kaydini
     * AuditInterceptor (hedef/gerekce) yazar; burada ayrica log tutulur (gerekce log'a yazilmaz).
     */
    public void disable(Long actorId, Long targetId) {
        User u = users.findById(targetId).filter(x -> x.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        AdminHierarchy.requireManageable(u);
        twoFactor.forceDisable(targetId);
        log.info("ADMIN_2FA_DISABLE admin={} userId={}", actorId, targetId);
        notifyUser(targetId);
    }

    /** Bildirim hatasi islemi bozmaz (servis sozlesmesi). */
    private void notifyUser(Long userId) {
        try {
            notifications.sendLocalized(userId, NotificationType.SYSTEM, "notif.twofactor.disabled.title",
                    "notif.twofactor.disabled.body", null, null);
        } catch (RuntimeException e) {
            log.warn("2FA kapatma bildirimi gonderilemedi userId={}: {}", userId, e.toString());
        }
    }
}
