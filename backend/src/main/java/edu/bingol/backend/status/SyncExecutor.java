package edu.bingol.backend.status;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Haber / menu / birim duyurusu ilk dolumu ve yonetici tetiklemeleri icin adlandirilmis TEK is parcacigi
 * (P07-B5). Onceden {@code CompletableFuture.runAsync} ortak ForkJoin havuzunu kullaniyordu: 2 vCPU'da
 * paralellik 1 oldugundan saatler suren bir ilk dolum havuzdaki diger isleri bekletebiliyordu.
 * Bilerek {@code java.util.concurrent.Executor} bean'i DEGILDIR: Spring Boot'un varsayilan gorev yurutucusunun
 * (ConditionalOnMissingBean) yerini almasin.
 */
@Component
public class SyncExecutor {

    private static final Logger log = LoggerFactory.getLogger(SyncExecutor.class);

    private final ExecutorService pool = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "content-sync");
        t.setDaemon(true);
        return t;
    });

    /** Gorevi sirayla calistirir; hata yutulur (servisler zaten exception sizdirmaz), kapaniyorsa sessizce birakilir. */
    public void run(Runnable task) {
        try {
            pool.execute(() -> {
                try {
                    task.run();
                } catch (RuntimeException e) {
                    log.warn("Arka plan senkronu hata verdi: {}", e.toString());
                }
            });
        } catch (RejectedExecutionException e) {
            log.debug("Senkron gorevi reddedildi (kapanis)");
        }
    }

    /** Bean bulunamadiysa (Spring disinda kurulan birim testleri) eski ortak havuz davranisi. */
    public static void dispatch(SyncExecutor executor, Runnable task) {
        if (executor != null) {
            executor.run(task);
        } else {
            CompletableFuture.runAsync(task);
        }
    }

    @PreDestroy
    void shutdown() {
        pool.shutdownNow();
    }
}
