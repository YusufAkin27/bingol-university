package edu.bingol.backend.moderation;

import edu.bingol.backend.accessban.AccessBan;
import edu.bingol.backend.accessban.AccessBanRepository;
import edu.bingol.backend.accessban.AccessGuard;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.HexFormat;
import java.util.Locale;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Ihlal defteri (T-058, A16-09/A16-10, karar K-15 onerisi: ozet + strike 12 ay, yeniden kayitta devral; acik sikayeti
 * olan hesabin silinmesi 7 gun bekler).
 *
 * <ul>
 *   <li>Silme: strike sayisi ve askiya alinmis olma durumu, e-posta HMAC ozetiyle deftere yazilir (ham adres tutulmaz).</li>
 *   <li>Yeniden kayit: ozet eslesirse strike'lar yeni hesaba {@code inherited} olarak devredilir; askiya alinmis
 *       hesabin adresi 403 ACCESS_BLOCKED alir (sebep acik edilmez).</li>
 *   <li>Silme bekletmesi: hakkinda acik rapor olan hesap ilk talepte 409 ACCOUNT_DELETE_ON_HOLD alir; rapor
 *       sonuclanirsa ya da bekleme dolarsa silinebilir.</li>
 * </ul>
 */
@Service
public class ViolationLedgerService {

    private static final Logger log = LoggerFactory.getLogger(ViolationLedgerService.class);

    /** Bir yeniden kayitta devralinacak en fazla strike (sisirmeye karsi sabit ust sinir). */
    static final int MAX_INHERIT = 20;

    private final ViolationLedgerRepository ledger;
    private final ModerationStrikeRepository strikes;
    private final StrikeService strikeService;
    private final AccountDeleteHolds holds;
    private final AccountDeleteHoldRepository holdRepo;
    private final JdbcTemplate jdbc;
    private final byte[] key;

    /** Kullanici erisim engeli (istege bagli: birim testlerinde yok): engelli hesap silinse de adres engelli kalir. */
    private AccessBanRepository bans;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setBans(AccessBanRepository bans) {
        this.bans = bans;
    }

    @Value("${app.moderation.ledger-retention-days:365}")
    private int retentionDays = 365;
    @Value("${app.moderation.delete-hold-days:7}")
    private int holdDays = 7;

    public ViolationLedgerService(ViolationLedgerRepository ledger, ModerationStrikeRepository strikes,
                                  StrikeService strikeService, AccountDeleteHolds holds,
                                  AccountDeleteHoldRepository holdRepo, JdbcTemplate jdbc,
                                  @Value("${app.moderation.ledger-hmac-key:}") String hmacKey,
                                  @Value("${jwt.secret:}") String jwtSecret) {
        this.ledger = ledger;
        this.strikes = strikes;
        this.strikeService = strikeService;
        this.holds = holds;
        this.holdRepo = holdRepo;
        this.jdbc = jdbc;
        this.key = (hmacKey != null && !hmacKey.isBlank() ? hmacKey : "ledger-hmac-v1:" + jwtSecret)
                .getBytes(StandardCharsets.UTF_8);
    }

    /** E-posta HMAC-SHA256 ozeti (kucuk harfli hex, 64 karakter). */
    public String digest(String email) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(
                    email.trim().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException("HMAC kullanilamiyor", e);
        }
    }

    /**
     * Hesap anonimlestirilirken (e-posta degismeden ONCE) cagrilir. Hata silmeyi engellemez: ayri transaction
     * (REQUIRES_NEW), yoksa deftere yazma hatasi cagiran silme islemini rollback-only yapardi.
     */
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    public void recordOnDeletion(Long userId, String email, UserStatus status) {
        holds.clear(userId);
        if (email == null || email.endsWith("@deleted.invalid")) {
            return;
        }
        try {
            Instant now = Instant.now();
            String dg = digest(email);
            long n = strikes.countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(userId,
                    now.minus(Duration.ofDays(retentionDays)));
            boolean banned = status == UserStatus.SUSPENDED
                    || (bans != null && bans.findLiveByValue(AccessBan.USER, String.valueOf(userId), now).isPresent());
            var existing = ledger.findByEmailDigest(dg);
            if (n == 0 && !banned) {
                existing.ifPresent(ledger::delete);
                return;
            }
            ViolationLedger l = existing.orElseGet(ViolationLedger::new);
            l.setEmailDigest(dg);
            l.setStrikeCount((int) Math.min(n, Integer.MAX_VALUE));
            l.setBanned(banned);
            l.setRecordedAt(now);
            l.setExpiresAt(now.plus(Duration.ofDays(retentionDays)));
            ledger.save(l);
        } catch (RuntimeException e) {
            log.warn("Ihlal defteri yazilamadi (user {}): {}", userId, e.toString());
        }
    }

    /** Yeni hesap olusunca: defterde kayit varsa strike'lari devral ve satiri tuket. Hata kaydi engellemez. */
    @Transactional
    public void inheritOnRegister(Long newUserId, String email) {
        try {
            Instant now = Instant.now();
            ledger.findByEmailDigest(digest(email)).filter(l -> l.getExpiresAt().isAfter(now)).ifPresent(l -> {
                int n = Math.min(l.getStrikeCount(), MAX_INHERIT);
                for (int i = 0; i < n; i++) {
                    ModerationStrike s = new ModerationStrike();
                    s.setUserId(newUserId);
                    s.setTargetType(ReportTargetType.USER);
                    s.setTargetId(newUserId);
                    s.setResolution(Report.Resolution.WARN);
                    s.setInherited(true);
                    strikes.save(s);
                }
                ledger.delete(l);
                if (n > 0) {
                    log.info("Ihlal defterinden {} strike devralindi (user {})", n, newUserId);
                    strikeService.recommendIfNeeded(newUserId);
                }
            });
        } catch (RuntimeException e) {
            log.warn("Ihlal devri yapilamadi (user {}): {}", newUserId, e.toString());
        }
    }

    /** Askiya alinmisken silinen hesabin adresi yeniden kayit olamaz (genel 403, sebep yok). */
    @Transactional(readOnly = true)
    public void requireNotBanned(String email) {
        Instant now = Instant.now();
        boolean banned = ledger.findByEmailDigest(digest(email))
                .filter(l -> l.isBanned() && l.getExpiresAt().isAfter(now)).isPresent();
        if (banned) {
            throw AccessGuard.accessBlocked();
        }
    }

    /** Kullanicinin kendisi ya da sahibi oldugu icerik hakkinda acik (OPEN) rapor sayisi. */
    @Transactional(readOnly = true)
    public long openReportsAbout(Long userId) {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM report r WHERE r.status = 'OPEN' AND ("
                + "(r.target_type IN ('USER', 'USER_AVATAR') AND r.target_id = ?) "
                + "OR (r.target_type = 'FEED_POST' AND r.target_id IN (SELECT id FROM post WHERE author_id = ?)) "
                + "OR (r.target_type IN ('POST', 'ANNOUNCEMENT') AND r.target_id IN (SELECT id FROM community_post WHERE author_id = ?)) "
                + "OR (r.target_type IN ('EVENT', 'EVENT_COVER') AND r.target_id IN (SELECT id FROM user_event WHERE created_by = ?)) "
                + "OR (r.target_type IN ('COMMUNITY', 'COMMUNITY_COVER') AND r.target_id IN (SELECT id FROM community WHERE owner_id = ?)) "
                + "OR (r.target_type = 'POLL' AND r.target_id IN (SELECT id FROM poll WHERE created_by = ?)) "
                + "OR (r.target_type = 'MESSAGE' AND r.target_id IN (SELECT id FROM message WHERE sender_id = ?)))",
                Long.class, userId, userId, userId, userId, userId, userId, userId);
        return n == null ? 0 : n;
    }

    /**
     * Hesap silme bekletmesi: acik rapor yoksa serbest; varsa ilk talep bekletmeyi baslatir ve 409 doner, bekleme
     * dolunca (rapor hala acik olsa da) silinebilir. Cagiran transaction geri alinsa da bekletme kaydi kalir.
     */
    public void requireDeletionAllowed(Long userId) {
        if (openReportsAbout(userId) == 0) {
            holds.clear(userId);
            return;
        }
        Instant release = holdRepo.findById(userId).map(AccountDeleteHold::getReleaseAt)
                .orElseGet(() -> holds.ensure(userId, holdDays));
        if (release.isAfter(Instant.now())) {
            throw new ApiException(HttpStatus.CONFLICT, "ACCOUNT_DELETE_ON_HOLD",
                    "Hesabınız hakkında incelenen şikâyet var; silme işlemi " + date(release) + " tarihine kadar bekletilir.",
                    date(release));
        }
    }

    private static String date(Instant t) {
        return t.atZone(ZoneId.of("Europe/Istanbul")).toLocalDate().toString();
    }

    @Scheduled(cron = "0 40 4 * * *", zone = "Europe/Istanbul")
    @Transactional
    public void purgeExpired() {
        try {
            Instant now = Instant.now();
            ledger.deleteExpired(now);
            holdRepo.deleteReleasedBefore(now.minus(Duration.ofDays(30)));
        } catch (RuntimeException e) {
            log.warn("Ihlal defteri temizlenemedi: {}", e.getClass().getSimpleName());
        }
    }
}
