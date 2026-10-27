package edu.bingol.backend.media.transcode;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Donusturme kuyrugu isleyicisi: {@code post_media.transcode_status = PENDING} satirlarini sahiplenir (atomik
 * UPDATE, SKIP LOCKED benzeri: ayni is iki kez alinmaz) ve en fazla {@code workers} tanesini ayni anda isler.
 * Coklu ornekte {@link SchedulerLock} ile yoklama tek ornege dusurulur. Yeniden baslamada PROCESSING'de
 * kalan isler {@code staleMinutes} sonra kuyruga geri alinir.
 */
@Component
public class TranscodeWorker {

    private static final Logger log = LoggerFactory.getLogger(TranscodeWorker.class);

    private final PostMediaTranscodeRepository repo;
    private final TranscodeService service;
    private final VideoTranscoder transcoder;
    private final TranscodeProperties props;
    private SchedulerLock lock;
    private ExecutorService pool;
    private final AtomicInteger done = new AtomicInteger();
    private final AtomicInteger failed = new AtomicInteger();

    @Autowired
    public TranscodeWorker(PostMediaTranscodeRepository repo, TranscodeService service, VideoTranscoder transcoder,
                           TranscodeProperties props) {
        this.repo = repo;
        this.service = service;
        this.transcoder = transcoder;
        this.props = props;
    }

    @Autowired(required = false)
    public void setLock(SchedulerLock lock) {
        this.lock = lock;
    }

    @Scheduled(fixedDelayString = "${app.media.transcode.poll-ms:5000}", initialDelayString = "${app.media.transcode.initial-delay-ms:20000}")
    public void tick() {
        if (!props.enabled()) {
            return;
        }
        Runnable r = this::drainOnce;
        try {
            if (lock != null) {
                lock.tryRun("media-transcode", Duration.ofMinutes(Math.max(5, props.timeoutSeconds() / 30 + 5)), r);
            } else {
                r.run();
            }
        } catch (RuntimeException e) {
            log.warn("Donusturme yoklamasi hatasi: {}", e.toString());
        }
    }

    /** Bir tur: bayat isleri geri al, en fazla `workers` isi paralel isle, sonra eski videolari sifrele. */
    int drainOnce() {
        int n = 0;
        if (transcoder.available()) {
            repo.resetStale(Instant.now().minus(Duration.ofMinutes(props.staleMinutes())));
            List<Long> claimed = new ArrayList<>();
            for (Long id : repo.pendingIds(PageRequest.of(0, props.workers()))) {
                if (repo.claim(id, Instant.now()) == 1) {
                    claimed.add(id);
                }
            }
            n = runAll(claimed);
        }
        if (props.encryptExisting()) {
            encryptLegacyBatch();
        }
        if (props.resealKeyId() != null && !props.resealKeyId().isBlank()) {
            for (Long id : repo.sealedWithKey(props.resealKeyId() + ":%", PageRequest.of(0, props.legacyBatch()))) {
                service.reseal(id);
            }
        }
        return n;
    }

    private int runAll(List<Long> ids) {
        if (ids.isEmpty()) {
            return 0;
        }
        List<Future<Boolean>> fs = new ArrayList<>();
        for (Long id : ids) {
            fs.add(pool().submit(() -> service.process(id)));
        }
        for (Future<Boolean> f : fs) {
            try {
                if (Boolean.TRUE.equals(f.get())) {
                    done.incrementAndGet();
                } else {
                    failed.incrementAndGet();
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (java.util.concurrent.ExecutionException e) {
                failed.incrementAndGet();
                log.warn("Donusturme isi hata verdi: {}", e.getCause() == null ? e.toString() : e.getCause().toString());
            }
        }
        return ids.size();
    }

    private void encryptLegacyBatch() {
        for (Long id : repo.plainVideoIds(PageRequest.of(0, props.legacyBatch()))) {
            service.encryptExisting(id);
        }
    }

    public int doneCount() {
        return done.get();
    }

    public int failedCount() {
        return failed.get();
    }

    private synchronized ExecutorService pool() {
        if (pool == null) {
            AtomicInteger i = new AtomicInteger();
            pool = Executors.newFixedThreadPool(props.workers(), r -> {
                Thread t = new Thread(r, "transcode-" + i.incrementAndGet());
                t.setDaemon(true);
                return t;
            });
        }
        return pool;
    }

    @jakarta.annotation.PreDestroy
    void shutdown() {
        if (pool != null) {
            pool.shutdownNow();
        }
    }
}
