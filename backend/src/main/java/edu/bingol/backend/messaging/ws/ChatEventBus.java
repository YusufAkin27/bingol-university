package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.crypto.BusCipher;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Cok sunuculu teslim koprusu. Olay once Redis kanalina yayinlanir; HER sunucu (yayinlayan dahil) kanali dinler ve
 * yalnizca kendi bagli kullanicilarina `/user/queue/<dest>` uzerinden iletir. Redis pub/sub kalici degildir:
 * kacirilan olaylar icin gercek kaynak veritabanidir (istemci yeniden baglaninca `after=` ile eksikleri ceker).
 */
@Component
public class ChatEventBus implements MessageListener {

    public static final String CHANNEL = "chat:events";

    /** Kanal zarfi: hedef kuyruk adi, alici kullanicilar ve yuk. */
    public record Envelope(String dest, List<Long> userIds, JsonNode payload) {}

    private static final Logger log = LoggerFactory.getLogger(ChatEventBus.class);

    private final StringRedisTemplate redis;
    private final SimpMessagingTemplate template;
    private final SimpUserRegistry registry;
    private final JsonMapper mapper;
    /** Redis'e yazilan her olay sifreli cerceve olarak gider (mesaj metni Redis'te duz durmaz). */
    private final BusCipher busCipher;

    public ChatEventBus(StringRedisTemplate redis, SimpMessagingTemplate template, SimpUserRegistry registry,
                        JsonMapper mapper, BusCipher busCipher) {
        this.busCipher = busCipher;
        this.redis = redis;
        this.template = template;
        this.registry = registry;
        this.mapper = mapper;
    }

    /** `dest`: messages | read-receipts | typing. Redis yayini basarisizsa yalnizca bu sunucudaki kullanicilara iletilir. */
    public void publish(String dest, Collection<Long> userIds, Object payload) {
        if (userIds.isEmpty()) {
            return;
        }
        Envelope env = new Envelope(dest, List.copyOf(userIds), mapper.valueToTree(payload));
        try {
            redis.convertAndSend(CHANNEL, busCipher.seal(mapper.writeValueAsString(env)));
        } catch (RuntimeException e) {
            log.warn("Redis yayini basarisiz, yalnizca yerel teslim: {}", e.toString());
            deliverLocal(env);
        }
    }

    private boolean suspended(Long uid) {
        try {
            return Boolean.TRUE.equals(redis.hasKey(JwtAuthFilter.SUSPENDED_KEY_PREFIX + uid));
        } catch (RuntimeException e) {
            return false; // Redis okunamazsa teslimi engelleme
        }
    }

    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            String json = busCipher.open(new String(message.getBody(), StandardCharsets.UTF_8));
            deliverLocal(mapper.readValue(json, Envelope.class));
        } catch (RuntimeException e) {
            log.warn("Gecersiz sohbet olayi atlandi: {}", e.toString());
        }
    }

    private void deliverLocal(Envelope env) {
        for (Long uid : env.userIds()) {
            String name = String.valueOf(uid);
            // Askiya alinan kullanicinin acik oturumu varsa bile (WS ortasinda askiya alma) teslim yapilmaz.
            if (registry.getUser(name) != null && !suspended(uid)) {
                template.convertAndSendToUser(name, "/queue/" + env.dest(), env.payload());
            }
        }
    }
}
