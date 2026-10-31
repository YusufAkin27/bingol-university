package edu.bingol.backend.messaging.ws;

import java.util.ArrayDeque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * `clientInboundChannel` icin OTURUM BASINA SIRALI yurutucu (T-037). Spring'in varsayilan havuzu bir istemcinin
 * ardisik STOMP cercevelerini (ornegin hizli art arda `chat.send`) farkli is parcaciklarinda ayni anda isler;
 * mesaj kimlikleri ve gecmis sirasi gonderim sirasindan sapardi (`setPreservePublishOrder` yalniz CIKIS kanalini
 * siralar). Tek is parcacikli kanal ise tum kullanicilari seri hale getirirdi.
 * <p>
 * Cozum: ayni WebSocket oturumunun gorevleri bir "serit"te (FIFO) sirayla calisir; farkli oturumlar paralel kalir.
 * Oturum anahtari, cerceveyi kanala koyan (oturumun kendi) is parcaciginda {@link KeyInterceptor#preSend} ile
 * ThreadLocal'e yazilir; {@code ExecutorSubscribableChannel} gorevi AYNI parcacikta {@link #execute}'a verdigi icin
 * gelis sirasi korunur. Anahtarsiz gorevler (oturumsuz mesajlar) dogrudan havuza gider.
 */
public final class SessionOrderedExecutor extends ThreadPoolTaskExecutor {

    private static final Logger log = LoggerFactory.getLogger(SessionOrderedExecutor.class);
    /** Bir serit bir parcaciga bu kadar gorev ust uste verirse siraya geri doner (tek oturum havuzu tutmasin). */
    static final int MAX_RUN = 32;

    private static final ThreadLocal<String> CURRENT_SESSION = new ThreadLocal<>();

    /** Oturum -> bekleyen gorevler. Haritada VAR olmak = o oturum icin bir yurutucu gorevi planlanmis/calisiyor. */
    private final Map<String, ArrayDeque<Runnable>> lanes = new ConcurrentHashMap<>();

    public SessionOrderedExecutor(int threads) {
        setCorePoolSize(threads);
        setMaxPoolSize(threads);
        setQueueCapacity(Integer.MAX_VALUE);
        setAllowCoreThreadTimeOut(true);
        setKeepAliveSeconds(60);
        setThreadNamePrefix("clientInboundChannel-");
    }

    @Override
    public void execute(Runnable task) {
        String session = CURRENT_SESSION.get();
        if (session == null) {
            super.execute(task);
            return;
        }
        boolean[] start = {false};
        lanes.compute(session, (k, lane) -> {
            if (lane == null) {
                lane = new ArrayDeque<>();
                start[0] = true;
            }
            lane.add(task);
            return lane;
        });
        if (start[0]) {
            schedule(session);
        }
    }

    private void schedule(String session) {
        try {
            super.execute(() -> drain(session));
        } catch (RuntimeException e) {
            lanes.remove(session); // kapanis: serit takili kalmasin
            throw e;
        }
    }

    private void drain(String session) {
        for (int i = 0; i < MAX_RUN; i++) {
            Runnable[] next = new Runnable[1];
            // poll + "bos serit = kaldir" TEK atomik adimda: yeni gelen gorev ya bu seritte bekler ya yeni serit acar
            lanes.computeIfPresent(session, (k, lane) -> {
                next[0] = lane.poll();
                return next[0] == null ? null : lane;
            });
            if (next[0] == null) {
                return;
            }
            try {
                next[0].run();
            } catch (Throwable t) {
                log.warn("STOMP gorevi basarisiz (oturum {}): {}", session, t.toString());
            }
        }
        schedule(session); // adil: siradaki oturumlara firsat ver, bu serit kuyruk sonuna doner
    }

    /** Bekleyen serit sayisi (test/izleme). */
    int laneCount() {
        return lanes.size();
    }

    /**
     * Gelen cerceveyi kanala koyan parcacikta oturum anahtarini ayarlar. Son siraya eklenir: onceki yakalayicilar
     * (kimlik) cerceveyi reddederse bu hic calismaz ve ThreadLocal'e dokunulmaz.
     */
    public static final class KeyInterceptor implements ChannelInterceptor {
        @Override
        public Message<?> preSend(Message<?> message, MessageChannel channel) {
            CURRENT_SESSION.set(SimpMessageHeaderAccessor.getSessionId(message.getHeaders()));
            return message;
        }

        @Override
        public void afterSendCompletion(Message<?> message, MessageChannel channel, boolean sent, Exception ex) {
            CURRENT_SESSION.remove();
        }
    }
}
