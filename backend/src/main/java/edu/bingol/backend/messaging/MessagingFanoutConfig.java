package edu.bingol.backend.messaging;

import java.util.concurrent.Executor;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Mesaj bildirim dagitimi icin kucuk, sinirli havuz: kuyruk dolarsa istek reddedilir (gonderici bloke olmaz). */
@Configuration
public class MessagingFanoutConfig {

    @Bean(name = "chatFanoutExecutor", destroyMethod = "shutdown")
    Executor chatFanoutExecutor() {
        ThreadPoolExecutor pool = new ThreadPoolExecutor(2, 4, 30, TimeUnit.SECONDS, new LinkedBlockingQueue<>(2000),
                r -> {
                    Thread t = new Thread(r, "chat-fanout");
                    t.setDaemon(true);
                    return t;
                });
        pool.allowCoreThreadTimeOut(true);
        return pool;
    }
}
