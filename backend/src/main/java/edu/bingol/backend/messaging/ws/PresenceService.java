package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos.PresenceView;
import edu.bingol.backend.moderation.BlockService;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import edu.bingol.backend.profile.privacy.Audience;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Cevrimici durumu. `presence:<id>` anahtari kisa TTL'lidir; her sunucu kendi bagli kullanicilari icin
 * anahtari periyodik yeniler (sunucu cokerse anahtar kendiliginden duser). `lastseen:<id>` son gorulme zamanidir.
 * Gizlilik: yalnizca ortak (aktif) konusmasi olan kullanicilar birbirinin durumunu gorur (T-025); ek olarak:
 * <ul>
 *   <li>yalniz birebir konusmayi paylasiyorsak karsi taraf o konusmada en az bir mesaj yazmis olmali (istenmeden acilan
 *       DM ile izleme yok);</li>
 *   <li>hedefin {@code presenceAudience} ayari ONLY_ME ise durum gorunmez (varsayilan SHARED_CONTEXT);</li>
 *   <li>engel iliskisi (iki yonde) ya da gorunmezlik: 404 DEGIL, sabit "cevrimdisi, son gorulme yok" doner; boylece
 *       engellenen taraf engellendigini ogrenemez (T-028).</li>
 * </ul>
 */
@Service
public class PresenceService {

    static final String ONLINE_PREFIX = "presence:";
    static final String LAST_SEEN_PREFIX = "lastseen:";
    static final Duration ONLINE_TTL = Duration.ofSeconds(30);
    static final Duration LAST_SEEN_TTL = Duration.ofDays(30);
    /** `viewing:<uid>` = acik sohbet kimligi; istemci 30 sn'de bir yeniler. */
    static final String VIEWING_PREFIX = "viewing:";
    static final Duration VIEWING_TTL = Duration.ofSeconds(45);
    /** `fg:<uid>`: uygulama on planda; istemci durum degisiminde ve 45 sn'de bir yeniler. */
    static final String FOREGROUND_PREFIX = "fg:";
    static final Duration FOREGROUND_TTL = Duration.ofSeconds(90);

    private static final Logger log = LoggerFactory.getLogger(PresenceService.class);

    private final StringRedisTemplate redis;
    private final SimpUserRegistry registry;
    private final ConversationMemberRepository members;
    private final BlockService blocks;

    public PresenceService(StringRedisTemplate redis, SimpUserRegistry registry, ConversationMemberRepository members,
                           BlockService blocks) {
        this.redis = redis;
        this.registry = registry;
        this.members = members;
        this.blocks = blocks;
    }

    /** Hedefin gorunurluk ayari (setter enjeksiyonu; yoksa varsayilan SHARED_CONTEXT davranisi). */
    private ProfilePrivacyRepository privacy;
    /** Ortak baglam + birebir karsilikliligi (setter enjeksiyonu; yoksa yalniz {@code shareConversation}). */
    private org.springframework.jdbc.core.JdbcTemplate jdbc;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPrivacy(ProfilePrivacyRepository privacy) {
        this.privacy = privacy;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setJdbc(org.springframework.jdbc.core.JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Sabit yanit: engelli/gizli hedefte gercek durum sizmaz. */
    static final PresenceView HIDDEN = new PresenceView(false, null);

    private static final String SHARED_CONTEXT_SQL = """
            SELECT COUNT(*) FROM conversation_member a
              JOIN conversation_member b ON a.conversation_id = b.conversation_id
              JOIN conversation c ON c.id = a.conversation_id
             WHERE a.user_id = ? AND b.user_id = ? AND a.left_at IS NULL AND b.left_at IS NULL
               AND (c.type <> 'DIRECT' OR EXISTS (
                     SELECT 1 FROM message m WHERE m.conversation_id = c.id AND m.sender_id = ?))
            """;

    public void markOnline(Long userId) {
        try {
            redis.opsForValue().set(ONLINE_PREFIX + userId, "1", ONLINE_TTL);
            redis.opsForValue().set(LAST_SEEN_PREFIX + userId, String.valueOf(Instant.now().toEpochMilli()), LAST_SEEN_TTL);
        } catch (RuntimeException e) {
            log.warn("Presence yazilamadi: {}", e.toString());
        }
    }

    public void markOffline(Long userId) {
        try {
            redis.delete(ONLINE_PREFIX + userId);
            redis.opsForValue().set(LAST_SEEN_PREFIX + userId, String.valueOf(Instant.now().toEpochMilli()), LAST_SEEN_TTL);
        } catch (RuntimeException e) {
            log.warn("Presence yazilamadi: {}", e.toString());
        }
    }

    /** Redis erisilemezse "cevrimdisi" sayilir (bildirim gider; fazladan bildirim eksik bildirimden iyidir). */
    public boolean isOnline(Long userId) {
        try {
            return Boolean.TRUE.equals(redis.hasKey(ONLINE_PREFIX + userId));
        } catch (RuntimeException e) {
            return false;
        }
    }

    /** Toplu sorgu (tek MGET): cevrimici olanlar. Redis erisilemezse bos kume (hepsi cevrimdisi sayilir). */
    public Set<Long> onlineAmong(Collection<Long> userIds) {
        if (userIds.isEmpty()) {
            return Set.of();
        }
        try {
            List<Long> ids = List.copyOf(userIds);
            List<String> values = redis.opsForValue().multiGet(ids.stream().map(id -> ONLINE_PREFIX + id).toList());
            Set<Long> online = new HashSet<>();
            for (int i = 0; values != null && i < values.size(); i++) {
                if (values.get(i) != null) {
                    online.add(ids.get(i));
                }
            }
            return online;
        } catch (RuntimeException e) {
            return Set.of();
        }
    }

    /**
     * Ortak (aktif) konusmasi yoksa 404 (kullanici varligi sizdirilmaz). Engel iliskisi, hedefin gizlilik ayari ya da
     * birebir karsilikliligi saglanmadiysa sabit "cevrimdisi" doner (200; engel/gizlilik ayrimi yapilamaz).
     */
    public PresenceView view(Long viewerId, Long targetId) {
        if (!viewerId.equals(targetId)) {
            if (!sharesContext(viewerId, targetId)) {
                if (!members.shareConversation(viewerId, targetId)) {
                    throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
                }
                return HIDDEN; // yalniz istenmemis birebir: karsi taraf yazmadi
            }
            if (blocks.isBlocked(viewerId, targetId) || !audienceAllows(targetId)) {
                return HIDDEN;
            }
        }
        boolean online = isOnline(targetId);
        String lastSeen = null;
        try {
            String v = redis.opsForValue().get(LAST_SEEN_PREFIX + targetId);
            if (v != null) {
                lastSeen = Instant.ofEpochMilli(Long.parseLong(v)).toString();
            }
        } catch (RuntimeException e) {
            // Redis yoksa son gorulme bilinmez
        }
        return new PresenceView(online, online ? null : lastSeen);
    }

    /**
     * Toplu: {@code targetIds} icinden durumu {@code viewerId}'e acik olanlar (view() ile ayni kurallar; sohbet listesi
     * "cevrimici" noktasi icin tek sorgu + tek ayar sorgusu).
     */
    public Set<Long> visibleAmong(Long viewerId, Collection<Long> targetIds) {
        Set<Long> ok = new HashSet<>(targetIds);
        ok.remove(viewerId);
        if (ok.isEmpty()) {
            return ok;
        }
        if (jdbc != null) {
            try {
                String in = String.join(",", java.util.Collections.nCopies(ok.size(), "?"));
                List<Object> args = new java.util.ArrayList<>();
                args.add(viewerId);
                args.addAll(ok);
                String sql = """
                        SELECT DISTINCT b.user_id FROM conversation_member a
                          JOIN conversation_member b ON a.conversation_id = b.conversation_id
                          JOIN conversation c ON c.id = a.conversation_id
                         WHERE a.user_id = ? AND b.user_id IN (%s) AND a.left_at IS NULL AND b.left_at IS NULL
                           AND (c.type <> 'DIRECT' OR EXISTS (
                                 SELECT 1 FROM message m WHERE m.conversation_id = c.id AND m.sender_id = b.user_id))
                        """.formatted(in);
                ok = new HashSet<>(jdbc.queryForList(sql, Long.class, args.toArray()));
            } catch (RuntimeException e) {
                log.warn("Presence toplu baglam sorgusu basarisiz: {}", e.toString());
                return Set.of(); // fail-closed
            }
        } else {
            ok.removeIf(id -> !members.shareConversation(viewerId, id));
        }
        ok.removeAll(blocks.hiddenFrom(viewerId));
        if (privacy != null && !ok.isEmpty()) {
            for (ProfilePrivacy p : privacy.findByUserIdIn(ok)) {
                if (p.getPresenceAudience() == Audience.ONLY_ME) {
                    ok.remove(p.getUserId());
                }
            }
        }
        return ok;
    }

    /** Toplu: durumu {@code viewerId}'e acik olanlardan cevrimici olanlar (acik olmayan = cevrimdisi sayilir). */
    public Set<Long> onlineVisibleTo(Long viewerId, Collection<Long> targetIds) {
        if (targetIds.isEmpty()) {
            return Set.of();
        }
        Set<Long> visible = visibleAmong(viewerId, targetIds);
        return visible.isEmpty() ? Set.of() : onlineAmong(visible);
    }

    /** Ortak konusma var ve (yalniz birebirse) hedef orada konusmus mu. SQL yoksa eski kural. */
    private boolean sharesContext(Long viewerId, Long targetId) {
        if (jdbc == null) {
            return members.shareConversation(viewerId, targetId);
        }
        try {
            Integer n = jdbc.queryForObject(SHARED_CONTEXT_SQL, Integer.class, viewerId, targetId, targetId);
            return n != null && n > 0;
        } catch (RuntimeException e) {
            log.warn("Presence baglam sorgusu basarisiz: {}", e.toString());
            return false; // fail-closed
        }
    }

    private boolean audienceAllows(Long targetId) {
        if (privacy == null) {
            return true;
        }
        ProfilePrivacy p = privacy.findById(targetId).orElse(null);
        Audience a = p == null ? Audience.SHARED_CONTEXT : p.getPresenceAudience();
        return a != Audience.ONLY_ME; // viewer zaten ortak konusmayi paylasiyor: SHARED_CONTEXT ve EVERYONE gorur
    }

    /** Kullanici bu sohbeti su an goruntuluyor (TTL'li). Goruntuleme on planda olmayi da ima eder. */
    public void setViewing(Long userId, Long conversationId) {
        try {
            redis.opsForValue().set(VIEWING_PREFIX + userId, String.valueOf(conversationId), VIEWING_TTL);
            redis.opsForValue().set(FOREGROUND_PREFIX + userId, "1", FOREGROUND_TTL);
        } catch (RuntimeException e) {
            log.warn("Viewing yazilamadi: {}", e.toString());
        }
    }

    /** Yalniz kayitli sohbet ayni ise siler (baska sohbete gecis sirasi yarisi bozulmasin). */
    public void clearViewing(Long userId, Long conversationId) {
        try {
            String cur = redis.opsForValue().get(VIEWING_PREFIX + userId);
            if (cur != null && cur.equals(String.valueOf(conversationId))) {
                redis.delete(VIEWING_PREFIX + userId);
            }
        } catch (RuntimeException e) {
            log.warn("Viewing silinemedi: {}", e.toString());
        }
    }

    public void setForeground(Long userId, boolean foreground) {
        try {
            if (foreground) {
                redis.opsForValue().set(FOREGROUND_PREFIX + userId, "1", FOREGROUND_TTL);
            } else {
                redis.delete(List.of(FOREGROUND_PREFIX + userId, VIEWING_PREFIX + userId));
            }
        } catch (RuntimeException e) {
            log.warn("Foreground yazilamadi: {}", e.toString());
        }
    }

    /** Adaylardan bu sohbeti su an goruntuleyenler. Redis yoksa bos (push gider: fazladan bildirim eksikten iyi). */
    public Set<Long> viewingAmong(Collection<Long> userIds, Long conversationId) {
        Set<Long> out = new HashSet<>();
        if (userIds.isEmpty()) {
            return out;
        }
        try {
            List<Long> ids = List.copyOf(userIds);
            List<String> v = redis.opsForValue().multiGet(ids.stream().map(id -> VIEWING_PREFIX + id).toList());
            String want = String.valueOf(conversationId);
            for (int i = 0; v != null && i < v.size(); i++) {
                if (want.equals(v.get(i))) {
                    out.add(ids.get(i));
                }
            }
        } catch (RuntimeException e) {
            out.clear();
        }
        return out;
    }

    /** Adaylardan uygulamasi on planda olanlar. */
    public Set<Long> foregroundAmong(Collection<Long> userIds) {
        Set<Long> out = new HashSet<>();
        if (userIds.isEmpty()) {
            return out;
        }
        try {
            List<Long> ids = List.copyOf(userIds);
            List<String> v = redis.opsForValue().multiGet(ids.stream().map(id -> FOREGROUND_PREFIX + id).toList());
            for (int i = 0; v != null && i < v.size(); i++) {
                if (v.get(i) != null) {
                    out.add(ids.get(i));
                }
            }
        } catch (RuntimeException e) {
            out.clear();
        }
        return out;
    }

    /** {@code lastseen:} yenileme sikligi: her N. heartbeat (10 sn x 6 = 60 sn); kapanista zaten yazilir. */
    static final int LAST_SEEN_EVERY = 6;
    private int refreshTick;

    /**
     * Bu sunucuya bagli kullanicilarin anahtarini yeniler (heartbeat). T-075 (A2-16): tum kullanicilar TEK boru hattinda
     * (eskiden kullanici basina 2 sirali SET = 5000 baglantida 10.000 gidis-donus/10 sn); {@code lastseen:} yalniz her
     * 60 sn'de bir ve baglanti/kapanista yazilir (yanit "cevrimici" iken lastseen zaten gosterilmez).
     */
    @Scheduled(fixedDelay = 10_000)
    void refreshLocal() {
        List<Long> ids = new java.util.ArrayList<>();
        for (SimpUser u : registry.getUsers()) {
            try {
                ids.add(Long.valueOf(u.getName()));
            } catch (NumberFormatException e) {
                // yalnizca sayisal kullanici kimlikleri atanir; digerleri yok sayilir
            }
        }
        if (ids.isEmpty()) {
            return;
        }
        boolean touchLastSeen = refreshTick++ % LAST_SEEN_EVERY == 0;
        String now = String.valueOf(Instant.now().toEpochMilli());
        long onlineSec = ONLINE_TTL.toSeconds();
        long lastSeenSec = LAST_SEEN_TTL.toSeconds();
        try {
            redis.executePipelined((org.springframework.data.redis.core.RedisCallback<Object>) conn -> {
                org.springframework.data.redis.connection.StringRedisConnection c =
                        (org.springframework.data.redis.connection.StringRedisConnection) conn;
                for (Long id : ids) {
                    c.setEx(ONLINE_PREFIX + id, onlineSec, "1");
                    if (touchLastSeen) {
                        c.setEx(LAST_SEEN_PREFIX + id, lastSeenSec, now);
                    }
                }
                return null;
            });
        } catch (RuntimeException e) {
            log.warn("Presence toplu yenileme basarisiz: {}", e.toString());
        }
    }
}
