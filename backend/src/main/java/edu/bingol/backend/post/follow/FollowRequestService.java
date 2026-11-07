package edu.bingol.backend.post.follow;

import edu.bingol.backend.common.AfterCommit;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.post.notify.PostNotifier;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.sql.Timestamp;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Takip istekleri (gizli hesap). İstek YALNIZ gizli hesaplara oluşur; herkese açık hesap doğrudan takip edilir.
 * Kurallar: kullanıcı başına en çok {@value #MAX_PENDING_OUT} bekleyen giden istek (422 FOLLOW_REQUEST_LIMIT); aynı
 * hedefe 24 saatte en çok {@value #PER_TARGET_PER_DAY} istek (429; red sonrası kötüye kullanım freni); kabulde gerçek takip
 * yazılır, istek silinir, istek sahibine FOLLOW_ACCEPTED bildirimi; red sessizdir. Gizli → açık geçişte bekleyen TÜM
 * istekler parçalı otomatik kabul edilir (bildirimsiz). Hesap silme/askıda istekler temizlenir.
 * İstek sonuçlandığında (kabul/red/geri çekme/otomatik kabul/engel/askı) hedefin kutusundaki FOLLOW_REQUEST bildirimi
 * SİLİNMEZ, OKUNDU işaretlenir (zil rozeti ve unread-count düşer).
 */
@Service
public class FollowRequestService {

    private static final Logger log = LoggerFactory.getLogger(FollowRequestService.class);

    public static final int MAX_PENDING_OUT = 200;
    public static final int PER_TARGET_PER_DAY = 3;
    /** Otomatik kabulde işlem başına istek sayısı (tek işlem büyümesin). */
    static final int AUTO_ACCEPT_CHUNK = 200;
    /** Arka plan bakımında (FollowRequestJob) hedef başına bir turda işlenecek en çok parça. */
    static final int AUTO_ACCEPT_INLINE_CHUNKS = 5;
    /**
     * Gizli → açık geçişte İSTEK İPLİĞİNDE (PUT /privacy) işlenecek en çok parça (A06#9): 1000 isteği tek istek
     * iş parçacığında kabul etmek (~6-8 bin sorgu, takipçi sayacı satırında uzun kilit) yerine ilk 200 hemen,
     * kalanı {@link FollowRequestJob} (varsayılan 5 dk) tamamlar.
     */
    static final int ON_PUBLIC_INLINE_CHUNKS = 1;

    /** Gelen istek satırı (yalnız istek sahibinin gizlilik ayarlarına uygun görünen alanları). */
    public record RequestItem(Long userId, String displayName, String avatarUrl, String department, String requestedAt) {}

    public record CountView(int count) {}

    private final JdbcTemplate jdbc;
    private final FollowWriter writer;
    private final UserRepository users;
    private final BlockService blocks;
    private final PublicProfileMapper profiles;
    private final RateLimiter limiter;
    private final ObjectProvider<PostNotifier> notifier;
    private final TransactionTemplate tx;
    private final NotificationRepository notifications;

    /** Bildirim birleşme anahtarı öneki (PostNotifier.onFollowRequest ile aynı). */
    static final String REQUEST_KEY_PREFIX = "followreq:";

    public FollowRequestService(JdbcTemplate jdbc, FollowWriter writer, UserRepository users, BlockService blocks,
                                PublicProfileMapper profiles, RateLimiter limiter, ObjectProvider<PostNotifier> notifier,
                                PlatformTransactionManager tm, NotificationRepository notifications) {
        this.jdbc = jdbc;
        this.writer = writer;
        this.users = users;
        this.blocks = blocks;
        this.profiles = profiles;
        this.limiter = limiter;
        this.notifier = notifier;
        this.notifications = notifications;
        this.tx = new TransactionTemplate(tm);
        // afterCommit icinden de cagrilir: o noktada dis islem bitmistir, yazimlar YENI islemde olmali
        this.tx.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    /** Bildirim yürütücüsü (A06#10; setter: kurucu imzası değişmesin; yoksa bildirim aynı iş parçacığında gider). */
    private edu.bingol.backend.post.notify.NotifyDispatcher dispatcher;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setDispatcher(edu.bingol.backend.post.notify.NotifyDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    private void notifyLater(Runnable r) {
        if (dispatcher != null) {
            dispatcher.run(r);
        } else {
            r.run();
        }
    }

    // ---------------------------------------------------------------- istek sahibi tarafı

    public boolean exists(Long requester, Long target) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM follow_request WHERE requester_id = ? AND target_id = ?",
                Integer.class, requester, target);
        return n != null && n > 0;
    }

    /**
     * Gizli hesaba istek oluşturur; zaten bekleyen istek varsa hiçbir şey yapmaz (idempotent, sınır yemez).
     * Çağıran: hedefin gizli, kullanıcının takipçi OLMADIĞI ve engel ilişkisi bulunmadığı doğrulanmıştır.
     */
    @Transactional
    public void request(Long me, Long target) {
        if (exists(me, target)) {
            return;
        }
        Integer pending = jdbc.queryForObject("SELECT COUNT(*) FROM follow_request WHERE requester_id = ?",
                Integer.class, me);
        if (pending != null && pending >= MAX_PENDING_OUT) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "FOLLOW_REQUEST_LIMIT",
                    "Çok fazla bekleyen takip isteğiniz var.", String.valueOf(MAX_PENDING_OUT));
        }
        limiter.check("followreq:" + me + ":" + target, PER_TARGET_PER_DAY, Duration.ofDays(1));
        int n;
        try {
            n = jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                    + "WHERE NOT EXISTS (SELECT 1 FROM follow_request WHERE requester_id = ? AND target_id = ?)",
                    me, target, me, target);
        } catch (DuplicateKeyException e) {
            return; // eş zamanlı çift istek: diğeri yazdı
        }
        if (n > 0) {
            AfterCommit.run(() -> notifyLater(() -> {
                PostNotifier pn = notifier.getIfAvailable();
                if (pn != null) {
                    pn.onFollowRequest(me, target);
                }
            }));
        }
    }

    /** İsteği geri çeker (idempotent). @return silindi mi */
    @Transactional
    public boolean withdraw(Long me, Long target) {
        boolean removed = jdbc.update("DELETE FROM follow_request WHERE requester_id = ? AND target_id = ?", me, target) > 0;
        // Geri cekilen istek artik yok: hedefin bildirim kutusundan da SILINIR (kabul/red okundu isaretler).
        deleteRequestNotification(target, me);
        return removed;
    }

    // ---------------------------------------------------------------- hedef (gelen) tarafı

    private static final String VISIBLE_FROM = "FROM follow_request r JOIN app_user u ON u.id = r.requester_id "
            + "AND u.status = 'ACTIVE' WHERE r.target_id = ? AND NOT EXISTS (SELECT 1 FROM user_block b WHERE "
            + "(b.blocker_id = r.target_id AND b.blocked_id = r.requester_id) "
            + "OR (b.blocker_id = r.requester_id AND b.blocked_id = r.target_id)) ";

    /** Gelen istekler, yeniden eskiye; imleç = istek kimliği. */
    @Transactional(readOnly = true)
    public CursorPage<RequestItem> incoming(Long me, Long cursor, int size) {
        int n = CursorPage.clampSize(size);
        List<Object[]> rows = jdbc.query("SELECT r.id, r.requester_id, r.created_at " + VISIBLE_FROM
                + (cursor == null ? "" : "AND r.id < ? ") + "ORDER BY r.id DESC LIMIT ?",
                (rs, i) -> new Object[] {rs.getLong(1), rs.getLong(2), rs.getTimestamp(3)},
                cursor == null ? new Object[] {me, n + 1} : new Object[] {me, cursor, n + 1});
        boolean more = rows.size() > n;
        List<Object[]> page = more ? rows.subList(0, n) : rows;
        List<Long> ids = page.stream().map(r -> (Long) r[1]).toList();
        Map<Long, PublicProfile> byId = new HashMap<>();
        if (!ids.isEmpty()) {
            profiles.mapAll(me, users.findAllById(ids)).forEach(p -> byId.put(p.id(), p));
        }
        List<RequestItem> items = page.stream().map(r -> {
            PublicProfile p = byId.get((Long) r[1]);
            Instant at = ((Timestamp) r[2]).toInstant();
            return p == null ? null
                    : new RequestItem(p.id(), p.displayName(), p.avatarUrl(), p.department(), at.toString());
        }).filter(java.util.Objects::nonNull).toList();
        return new CursorPage<>(items, more ? (Long) page.get(page.size() - 1)[0] : null);
    }

    @Transactional(readOnly = true)
    public int count(Long me) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) " + VISIBLE_FROM, Integer.class, me);
        return n == null ? 0 : n;
    }

    /**
     * İsteği kabul eder (idempotent): istek varsa silinir ve gerçek takip yazılır; istek sahibine bildirim.
     * Engel ilişkisi/pasif hesapta istek sessizce silinir, takip oluşmaz.
     * @return güncel bekleyen istek sayısı
     */
    @Transactional
    public int accept(Long me, Long requesterId) {
        boolean followed = acceptOne(requesterId, me);
        markRequestNotificationRead(me, requesterId);
        if (followed) {
            AfterCommit.run(() -> notifyLater(() -> {
                PostNotifier pn = notifier.getIfAvailable();
                if (pn != null) {
                    pn.onFollowAccepted(me, requesterId);
                }
            }));
        }
        return count(me);
    }

    /** İsteği reddeder (idempotent, SESSİZ: istek sahibine bildirim yok). @return güncel bekleyen istek sayısı */
    @Transactional
    public int decline(Long me, Long requesterId) {
        jdbc.update("DELETE FROM follow_request WHERE requester_id = ? AND target_id = ?", requesterId, me);
        markRequestNotificationRead(me, requesterId);
        return count(me);
    }

    /** İsteği siler; uygunsa takibi yazar. @return gerçek takip OLUŞTU mu */
    private boolean acceptOne(Long requesterId, Long target) {
        int n = jdbc.update("DELETE FROM follow_request WHERE requester_id = ? AND target_id = ?", requesterId, target);
        if (n == 0) {
            return false;
        }
        User r = users.findById(requesterId).orElse(null);
        if (r == null || !r.isActive() || blocks.isBlocked(requesterId, target)) {
            return false;
        }
        return writer.create(requesterId, target);
    }

    // ---------------------------------------------------------------- gizli -> açık geçiş, bakım

    /**
     * Hedefin bekleyen TÜM isteklerini otomatik kabul eder; {@code AUTO_ACCEPT_CHUNK} istekli ayrı işlemlerle.
     * Bildirim yok (toplu bildirim fırtınası olmasın). @return kabul edilen takip sayısı
     */
    public int acceptAllPending(Long target, int maxChunks) {
        int accepted = 0;
        for (int i = 0; i < maxChunks; i++) {
            List<Long> ids = jdbc.queryForList("SELECT requester_id FROM follow_request WHERE target_id = ? "
                    + "ORDER BY id LIMIT ?", Long.class, target, AUTO_ACCEPT_CHUNK);
            if (ids.isEmpty()) {
                break;
            }
            Integer done = tx.execute(st -> {
                int c = 0;
                for (Long requesterId : ids) {
                    if (acceptOne(requesterId, target)) {
                        c++;
                    }
                }
                return c;
            });
            accepted += done == null ? 0 : done;
        }
        // hedef artik herkese acik: bekleyen istek bildirimlerinin hepsi gecersiz (tek sorgu)
        // (afterCommit icinden de cagrilir: YENI islemde, yoksa tamamlanmis dis islemin kaynagina baglanip hata verir)
        try {
            tx.executeWithoutResult(st -> markAllRequestNotificationsRead(target));
        } catch (RuntimeException e) {
            log.warn("Takip istegi bildirimleri okundu isaretlenemedi (kullanici {}): {}", target, e.toString());
        }
        return accepted;
    }

    /** Gizli → açık geçişte çağrılır (PrivacyService): ilk parçalar hemen, kalanı {@link FollowRequestJob}. */
    public void onBecamePublic(Long target) {
        try {
            int n = acceptAllPending(target, ON_PUBLIC_INLINE_CHUNKS);
            if (n > 0) {
                log.info("Gizli->acik gecis: {} bekleyen istek otomatik kabul edildi (kullanici {})", n, target);
            }
        } catch (RuntimeException e) {
            log.warn("Otomatik kabul tamamlanamadi (kullanici {}): {}", target, e.toString());
        }
    }

    /** Artık herkese açık hesaplara kalmış bekleyen istekleri tamamlar (iş her çalışmada en çok 50 hedef). */
    public int healPublicTargets() {
        List<Long> targets = jdbc.queryForList("SELECT DISTINCT r.target_id FROM follow_request r WHERE NOT EXISTS "
                + "(SELECT 1 FROM profile_privacy p WHERE p.user_id = r.target_id AND p.private_account = TRUE) LIMIT 50",
                Long.class);
        int total = 0;
        for (Long t : targets) {
            total += acceptAllPending(t, AUTO_ACCEPT_INLINE_CHUNKS);
        }
        return total;
    }

    /** Hesap silme/askı: kullanıcının gönderdiği ve aldığı tüm bekleyen istekler silinir. */
    @Transactional
    public void purgeUser(Long uid) {
        // gonderdigi isteklerin hedeflerindeki bildirimler (silmeden once hedefler okunur; en cok MAX_PENDING_OUT)
        List<Long> targets = jdbc.queryForList("SELECT target_id FROM follow_request WHERE requester_id = ?",
                Long.class, uid);
        jdbc.update("DELETE FROM follow_request WHERE requester_id = ? OR target_id = ?", uid, uid);
        for (Long t : targets) {
            markRequestNotificationRead(t, uid);
        }
        markAllRequestNotificationsRead(uid);
    }

    /** İki taraf arasındaki bekleyen istekler (engelleme). */
    @Transactional
    public void dropBetween(Long a, Long b) {
        jdbc.update("DELETE FROM follow_request WHERE (requester_id = ? AND target_id = ?) "
                + "OR (requester_id = ? AND target_id = ?)", a, b, b, a);
        markRequestNotificationRead(a, b);
        markRequestNotificationRead(b, a);
    }

    // ---------------------------------------------------------------- bildirim kutusu

    /** Hedefin kutusundaki, bu istek sahibine ait okunmamış FOLLOW_REQUEST bildirimini okundu yapar (en iyi çaba). */
    private void markRequestNotificationRead(Long target, Long requesterId) {
        try {
            notifications.markReadByTypeAndCollapseKey(target, NotificationType.FOLLOW_REQUEST,
                    REQUEST_KEY_PREFIX + requesterId, Instant.now());
        } catch (RuntimeException e) {
            log.warn("Takip istegi bildirimi okundu isaretlenemedi (kullanici {}): {}", target, e.toString());
        }
    }

    /** Geri çekilen isteğin hedefin kutusundaki FOLLOW_REQUEST bildirimini siler (en iyi çaba). */
    private void deleteRequestNotification(Long target, Long requesterId) {
        try {
            notifications.deleteByTypeAndCollapseKey(target, NotificationType.FOLLOW_REQUEST,
                    REQUEST_KEY_PREFIX + requesterId);
        } catch (RuntimeException e) {
            log.warn("Takip istegi bildirimi silinemedi (kullanici {}): {}", target, e.toString());
        }
    }

    /** Hedefin tüm okunmamış FOLLOW_REQUEST bildirimlerini tek sorguyla okundu yapar (en iyi çaba). */
    private void markAllRequestNotificationsRead(Long target) {
        try {
            notifications.markReadByTypeAndCollapseKeyLike(target, NotificationType.FOLLOW_REQUEST,
                    escapeLike(REQUEST_KEY_PREFIX) + "%", Instant.now());
        } catch (RuntimeException e) {
            log.warn("Takip istegi bildirimleri okundu isaretlenemedi (kullanici {}): {}", target, e.toString());
        }
    }

    /** LIKE kacisi: {@code \}, {@code %}, {@code _}. */
    static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
