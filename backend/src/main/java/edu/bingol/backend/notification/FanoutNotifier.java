package edu.bingol.backend.notification;

import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import edu.bingol.backend.common.AfterCommit;

/**
 * Uye/katilimci/kitle bildirimlerini ISTEK is parcaciginden ve acik islemden cikarir (FINAL-ALL, P05/P07/P08
 * "ertelenen" kalemleri). Cagiran servis alici listesini ve bildirim cagrilarini bir {@link Runnable} icinde verir;
 * is, cagiran islem COMMIT olduktan sonra (islem yoksa hemen) kucuk, sinirli bir havuzda calisir. Boylece:
 * <ul>
 *   <li>istek kulup/etkinlik uye sayisiyla yavaslamaz, satir kilidi ve baglanti bildirim boyunca tutulmaz;</li>
 *   <li>geri alinan islem bildirim gondermez (commit sonrasi);</li>
 *   <li>bildirim hatasi istegi bozmaz (is icinde yakalanir ve loglanir).</li>
 * </ul>
 * Kuyruk dolarsa is atilir (WARN + sayac): bildirim kritik veri degildir, istek bloke edilmez. Havuz kucuktur
 * (2 is parcacigi) cunku her is parca basina sabit sayida sorgu calistiran {@code sendTemplatedBulk} kullanir.
 * <p>
 * Birim testleri icin servisler bu bileseni istege bagli (null) enjekte eder; yoksa is ayni is parcaciginda calisir.
 */
@Component
public class FanoutNotifier {

    private static final Logger log = LoggerFactory.getLogger(FanoutNotifier.class);

    static final int THREADS = 2;
    static final int QUEUE = 500;

    private final ThreadPoolExecutor pool;
    private final AtomicLong rejected = new AtomicLong();
    /** Yalniz test: true ise isler commit/havuz beklenmeden ayni is parcaciginda calisir (`app.notification.fanout-inline`). */
    private final boolean inline;

    public FanoutNotifier() {
        this(false);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public FanoutNotifier(@org.springframework.beans.factory.annotation.Value("${app.notification.fanout-inline:false}") boolean inline) {
        this.inline = inline;
        this.pool = new ThreadPoolExecutor(THREADS, THREADS, 30, TimeUnit.SECONDS, new LinkedBlockingQueue<>(QUEUE), r -> {
            Thread t = new Thread(r, "notify-fanout");
            t.setDaemon(true);
            return t;
        });
        this.pool.allowCoreThreadTimeOut(true);
    }

    /** Islem varsa commit sonrasi, yoksa hemen; isi havuza devreder. Exception sizdirmaz. */
    public void afterCommit(String what, Runnable job) {
        if (inline) {
            runSafely(what, job);
            return;
        }
        AfterCommit.run(() -> submit(what, job));
    }

    /** Isi havuza verir; kuyruk dolarsa atilir (sayac + WARN). */
    public void submit(String what, Runnable job) {
        try {
            pool.execute(() -> runSafely(what, job));
        } catch (RejectedExecutionException e) {
            long n = rejected.incrementAndGet();
            log.warn("Bildirim dagitimi kuyrugu dolu, is atildi ({}; toplam {})", what, n);
        }
    }

    /** Servis tarafi: {@code fanout} yoksa (birim testi) ayni is parcaciginda, varsa commit sonrasi havuzda calistirir. */
    public static void dispatch(FanoutNotifier fanout, String what, Runnable job) {
        if (fanout == null) {
            runSafely(what, job);
        } else {
            fanout.afterCommit(what, job);
        }
    }

    public long rejectedCount() {
        return rejected.get();
    }

    private static void runSafely(String what, Runnable job) {
        try {
            job.run();
        } catch (RuntimeException e) {
            log.warn("Bildirim dagitimi basarisiz ({}): {}", what, e.toString());
        }
    }
}
