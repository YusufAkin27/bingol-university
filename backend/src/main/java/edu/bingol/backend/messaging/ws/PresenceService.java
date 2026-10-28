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
 * Gizlilik: yalnizca ortak (aktif) konusmasi olan ve engel iliskisi olmayan kullanicilar birbirinin durumunu gorur.
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

    /** Ortak konusmasi yoksa ya da engel varsa 404 (kullanici varligi sizdirilmaz). */
    public PresenceView view(Long viewerId, Long targetId) {
        if (!viewerId.equals(targetId)
                && (!members.shareConversation(viewerId, targetId) || blocks.isBlocked(viewerId, targetId))) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
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

    /** Bu sunucuya bagli kullanicilarin anahtarini yeniler (heartbeat). */
    @Scheduled(fixedDelay = 10_000)
    void refreshLocal() {
        for (SimpUser u : registry.getUsers()) {
            try {
                markOnline(Long.valueOf(u.getName()));
            } catch (NumberFormatException e) {
                // yalnizca sayisal kullanici kimlikleri atanir; digerleri yok sayilir
            }
        }
    }
}
