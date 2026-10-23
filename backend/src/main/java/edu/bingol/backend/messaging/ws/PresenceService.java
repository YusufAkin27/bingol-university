package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos.PresenceView;
import edu.bingol.backend.moderation.BlockService;
import java.time.Duration;
import java.time.Instant;
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
