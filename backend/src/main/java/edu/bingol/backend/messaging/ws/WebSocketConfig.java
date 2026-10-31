package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import java.net.InetSocketAddress;
import java.time.Duration;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketTransportRegistration;
import org.springframework.web.socket.server.HandshakeInterceptor;

/**
 * STOMP yapilandirmasi. Uygulama oneki /app, teslim yalnizca kullaniciya ozel /user/queue/* (broker /topic'e KAPALI).
 * Ham WebSocket (/ws), SockJS yok. Dis sunuculara olceklenme {@link ChatEventBus} ile Redis pub/sub uzerindendir.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private static final Logger log = LoggerFactory.getLogger(WebSocketConfig.class);

    private final StompAuthInterceptor stompAuth;
    private final TokenExpiryGuard expiryGuard;
    private final RateLimiter limiter;
    private final String[] allowedOrigins;

    private final edu.bingol.backend.common.ClientIp clientIp;
    private final edu.bingol.backend.accessban.ClientContexts contexts;

    public WebSocketConfig(StompAuthInterceptor stompAuth, TokenExpiryGuard expiryGuard, RateLimiter limiter,
                           edu.bingol.backend.common.ClientIp clientIp,
                           edu.bingol.backend.accessban.ClientContexts contexts,
                           @Value("${app.messaging.allowed-origins:}") String[] allowedOrigins) {
        this.clientIp = clientIp;
        this.contexts = contexts;
        this.stompAuth = stompAuth;
        this.expiryGuard = expiryGuard;
        this.limiter = limiter;
        this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        var endpoint = registry.addEndpoint("/ws").addInterceptors(new IpRateLimitInterceptor());
        // Mobil istemci Origin gondermez; web istemcisi icin izinli origin'ler acikca verilir (* kullanilmaz).
        if (allowedOrigins.length > 0) {
            endpoint.setAllowedOriginPatterns(allowedOrigins);
        }
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        ThreadPoolTaskScheduler heartbeat = new ThreadPoolTaskScheduler();
        heartbeat.setPoolSize(1);
        heartbeat.setThreadNamePrefix("ws-heartbeat-");
        heartbeat.setDaemon(true);
        heartbeat.initialize();
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
        // Istemciye TESLIM (cikis) sirasi korunur. Gelen komutlarin oturum basina sirasi ayri korunur:
        // configureClientInboundChannel -> SessionOrderedExecutor (yalniz bu bayrak giris sirasini SIRALAMAZ).
        registry.setPreservePublishOrder(true);
        registry.enableSimpleBroker("/queue").setHeartbeatValue(new long[] {10_000, 10_000}).setTaskScheduler(heartbeat);
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        // T-037: ayni oturumun cerceveleri (ornegin hizli art arda chat.send) sirayla islenir, farkli oturumlar paralel.
        // setPreservePublishOrder yalniz istemciye CIKIS sirasini korur; GIRIS sirasini bu yurutucu korur.
        // KeyInterceptor kimlik denetiminden SONRA gelmelidir (reddedilen cerceve oturum anahtari yazmaz).
        registration.taskExecutor(new SessionOrderedExecutor(Math.max(8, 2 * Runtime.getRuntime().availableProcessors())));
        registration.interceptors(stompAuth, new SessionOrderedExecutor.KeyInterceptor());
    }

    @Override
    public void configureWebSocketTransport(WebSocketTransportRegistration registration) {
        registration.addDecoratorFactory(expiryGuard::decorate)
                .setMessageSizeLimit(16 * 1024)
                .setSendBufferSizeLimit(512 * 1024)
                .setSendTimeLimit(10_000)
                .setTimeToFirstMessage(10_000); // CONNECT gondermeyen baglanti kapatilir
    }

    /** Diger sunuculardan gelen sohbet olaylarini dinler (her sunucu kendi kullanicilarina iletir). */
    @Bean
    RedisMessageListenerContainer chatEventListenerContainer(RedisConnectionFactory cf, ChatEventBus bus,
            @org.springframework.beans.factory.annotation.Value("${app.messaging.redis-listener:true}") boolean autoStart) {
        RedisMessageListenerContainer c = new RedisMessageListenerContainer();
        c.setAutoStartup(autoStart); // testlerde Redis olmadan baglam acilabilsin diye kapatilabilir
        c.setConnectionFactory(cf);
        c.addMessageListener(bus, new ChannelTopic(ChatEventBus.CHANNEL));
        return c;
    }

    /**
     * El sikisma asiri baglanti denemesine karsi IP basina dakikada 600 (kampus NAT'i icin genis tutuldu).
     * Redis erisilemezse el sikismaya izin verilir; kimlik zaten CONNECT'te zorunludur.
     */
    class IpRateLimitInterceptor implements HandshakeInterceptor {
        @Override
        public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response, WebSocketHandler handler,
                                       Map<String, Object> attributes) {
            InetSocketAddress addr = request.getRemoteAddress();
            String remote = addr == null || addr.getAddress() == null ? null : addr.getAddress().getHostAddress();
            String ip = clientIp.resolve(remote, request.getHeaders().getFirst("X-Forwarded-For"));
            // CONNECT'te cihaz/IP engeli icin istemci baglami oturuma yazilir (ham cihaz kimligi degil, ozeti)
            attributes.put(StompAuthInterceptor.CONTEXT_ATTR, contexts.build(ip,
                    request.getHeaders().getFirst(edu.bingol.backend.accessban.ClientContexts.DEVICE_HEADER),
                    request.getHeaders().getFirst(edu.bingol.backend.accessban.ClientContexts.PLATFORM_HEADER),
                    request.getHeaders().getFirst(edu.bingol.backend.accessban.ClientContexts.VERSION_HEADER)));
            try {
                limiter.check("ws:ip:" + ip, 600, Duration.ofMinutes(1));
            } catch (ApiException e) {
                response.setStatusCode(HttpStatus.TOO_MANY_REQUESTS);
                return false;
            } catch (RuntimeException e) {
                log.warn("WS el sikisma limiti kontrol edilemedi: {}", e.toString());
            }
            return true;
        }

        @Override
        public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response, WebSocketHandler handler,
                                   Exception exception) {
            // gerekmez
        }
    }
}
