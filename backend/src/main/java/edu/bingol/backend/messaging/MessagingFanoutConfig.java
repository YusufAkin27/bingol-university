package edu.bingol.backend.messaging;

import java.util.concurrent.Executor;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Mesaj bildirim dagitimi icin kucuk, sinirli havuz: kuyruk dolarsa istek reddedilir (gonderici bloke olmaz).
 * Reddedilen is kaybolmaz: {@link ChatNotifyFanout} onu sayar (`chat_fanout_rejected_total`), WARN yazar ve bekletip
 * bir gorev bitince yeniden kuyruga alir. Kuyrukta sohbet basina en cok bir gorev bulunur (birlestirme), bu yuzden
 * 2000 kapasite "2000 farkli sohbet" demektir.
 * <p>
 * core = max = 4: sinirli kuyrukta `max` hic devreye girmezdi (eski 2/4 ayar fiilen 2 is parcacigiydi). Her gorev
 * artik alici basina degil PARCA basina birkac sorgu calistirir (500 alici ~ 4 parca), bu yuzden 4 is parcacigi yeter
 * ve Hikari havuzunu (varsayilan 10) doyurmaz.
 */
@Configuration
public class MessagingFanoutConfig {

    static final int THREADS = 4;
    static final int QUEUE = 2000;

    @Bean(name = "chatFanoutExecutor", destroyMethod = "shutdown")
    Executor chatFanoutExecutor() {
        ThreadPoolExecutor pool = new ThreadPoolExecutor(THREADS, THREADS, 30, TimeUnit.SECONDS,
                new LinkedBlockingQueue<>(QUEUE), r -> {
                    Thread t = new Thread(r, "chat-fanout");
                    t.setDaemon(true);
                    return t;
                });
        pool.allowCoreThreadTimeOut(true);
        return pool;
    }
}
