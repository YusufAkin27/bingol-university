package edu.bingol.backend.messaging;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Sohbet mesaji bildirim dagitimi icin sohbet basina birlestirme (T-035). Ayni sohbete ait, henuz CALISMAMIS bir
 * dagitim varken yeni mesaj gelirse yeni gorev acilmaz: bekleyen is son mesajin bilgisiyle guncellenir ve mesaj sayaci
 * artar (alicilar tek "N yeni mesaj" bildirimi alir; bildirim satirinin sayaci yine mesaj kadar artar). Havuz bosken
 * (her gorev hemen calisir) davranis eskisiyle aynidir; birikme yalniz asiri yukte devreye girer.
 * <p>
 * Kuyruk dolarsa gorev SESSIZCE atilmaz: ret sayilir ve WARN yazilir, is {@code overflow} kumesinde bekler ve ya ayni
 * sohbetin sonraki mesajinda ya da herhangi bir gorev bitince yeniden kuyruga alinmaya calisilir. Yalniz bekleyen
 * sohbet sayisi {@link #MAX_PENDING}'i asarsa en yeni is atilir (ERROR + sayac).
 */
final class ChatNotifyFanout {

    /** Bir sohbet icin dagitim isi: son mesajin bilgileri ve birlestirilen mesaj adedi. */
    record Job(Long senderId, Long conversationId, String groupTitle, String preview, boolean previewOptInOnly,
               Map<String, String> data, List<Long> candidates, int count) {
        Job merged(Job latest) {
            return new Job(latest.senderId, latest.conversationId, latest.groupTitle, latest.preview,
                    latest.previewOptInOnly, latest.data, latest.candidates, count + latest.count);
        }
    }

    /** Bekleyen sohbet sayisi ust siniri (bellek korumasi). */
    static final int MAX_PENDING = 10_000;
    /** Bir gorev bitince yeniden kuyruga alinmaya calisilan en fazla sohbet. */
    private static final int DRAIN_BATCH = 16;

    private static final Logger log = LoggerFactory.getLogger(ChatNotifyFanout.class);

    private final Consumer<Job> worker;
    private final Object lock = new Object();
    private final Map<Long, Job> pending = new HashMap<>();
    /** Kuyruga alinamamis (havuz dolu) sohbetler; sirayla yeniden denenir. */
    private final Set<Long> overflow = new LinkedHashSet<>();

    private final AtomicLong coalesced = new AtomicLong();
    private final AtomicLong rejected = new AtomicLong();
    private final AtomicLong dropped = new AtomicLong();

    ChatNotifyFanout(Consumer<Job> worker) {
        this.worker = worker;
    }

    /** Prometheus: sohbet bildirim dagitimi sayaclari (havuz doygunlugu uyarisi icin). */
    void bind(MeterRegistry registry) {
        Gauge.builder("chat_fanout_rejected_total", rejected, AtomicLong::get).register(registry);
        Gauge.builder("chat_fanout_coalesced_total", coalesced, AtomicLong::get).register(registry);
        Gauge.builder("chat_fanout_dropped_total", dropped, AtomicLong::get).register(registry);
        Gauge.builder("chat_fanout_pending", this, ChatNotifyFanout::pendingCount).register(registry);
    }

    int pendingCount() {
        synchronized (lock) {
            return pending.size();
        }
    }

    long rejectedCount() {
        return rejected.get();
    }

    long coalescedCount() {
        return coalesced.get();
    }

    long droppedCount() {
        return dropped.get();
    }

    /** Dagitimi siraya koyar ya da bekleyen ayni sohbet islemiyle birlestirir. */
    void submit(Executor executor, Job job) {
        Long conv = job.conversationId();
        synchronized (lock) {
            Job prev = pending.get(conv);
            if (prev != null) {
                pending.put(conv, prev.merged(job)); // henuz calismadi: son mesaj kazanir, sayac toplanir
                coalesced.incrementAndGet();
                if (!overflow.contains(conv)) {
                    return; // zaten kuyrukta; calisirken bu bilgiyi alir
                }
                // kuyruga alinamamisti: asagida yeniden denenir
            } else {
                if (pending.size() >= MAX_PENDING) {
                    dropped.incrementAndGet();
                    log.error("Bildirim dagitimi biriktirme siniri asildi ({}), sohbet {} icin bildirim atlandi",
                            MAX_PENDING, conv);
                    return;
                }
                pending.put(conv, job);
            }
        }
        trySubmit(executor, conv);
    }

    private void trySubmit(Executor executor, Long conv) {
        try {
            executor.execute(() -> run(executor, conv));
            synchronized (lock) {
                overflow.remove(conv);
            }
        } catch (RejectedExecutionException e) {
            long n = rejected.incrementAndGet();
            synchronized (lock) {
                overflow.add(conv);
            }
            log.warn("Bildirim dagitim kuyrugu dolu: sohbet {} bekletiliyor (toplam ret {}, bekleyen {})", conv, n,
                    pendingCount());
        }
    }

    private void run(Executor executor, Long conv) {
        Job job;
        synchronized (lock) {
            job = pending.remove(conv);
            overflow.remove(conv);
        }
        try {
            if (job != null) {
                worker.accept(job);
            }
        } catch (RuntimeException e) {
            log.warn("Bildirim dagitimi basarisiz (sohbet {}): {}", conv, e.toString());
        } finally {
            drain(executor);
        }
    }

    /** Bir gorev bitti, kuyrukta yer acildi: reddedilmis sohbetleri yeniden kuyruga almayi dene. */
    private void drain(Executor executor) {
        List<Long> retry;
        synchronized (lock) {
            if (overflow.isEmpty()) {
                return;
            }
            retry = new ArrayList<>(overflow.stream().limit(DRAIN_BATCH).toList());
        }
        for (Long conv : retry) {
            long before = rejected.get();
            trySubmit(executor, conv);
            if (rejected.get() != before) {
                return; // kuyruk hala dolu
            }
        }
    }
}
