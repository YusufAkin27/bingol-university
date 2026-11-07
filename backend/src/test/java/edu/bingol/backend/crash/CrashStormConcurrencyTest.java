package edu.bingol.backend.crash;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.crash.CrashDtos.ReportRequest;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * FIX-P09 (A08#1, A09#1): cokme firtinasinda tek crash_group satirina yigilma olmaz. DB mock'ludur (PostgreSQL'e ozel
 * SQL'in kendisi scripts/smoke-crash-reports.sh ile dogrulanir); burada es zamanlilik kapisi, imza freni, tasma
 * sayaci ve SQL'de FOR UPDATE bulunmamasi sinanir.
 */
class CrashStormConcurrencyTest {

    private static final Instant NOW = Instant.parse("2026-11-01T10:00:30Z");

    private NamedParameterJdbcTemplate jdbc;
    private CrashThrottle throttle;
    private CrashService service;
    private final AtomicInteger inflight = new AtomicInteger();
    private final AtomicInteger maxInflight = new AtomicInteger();
    private final AtomicInteger persisted = new AtomicInteger();
    private final AtomicInteger allowedSoFar = new AtomicInteger();
    private final AtomicInteger overflow = new AtomicInteger();
    private final ConcurrentLinkedQueue<String> sql = new ConcurrentLinkedQueue<>();
    private volatile CrashService.GroupState state = new CrashService.GroupState(7, "NEW", "1.0.0", null, null, 5, false);
    private volatile int reopenUpdateCount = 1;
    private volatile long perWriteMs = 20;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        jdbc = mock(NamedParameterJdbcTemplate.class);
        throttle = mock(CrashThrottle.class);
        when(throttle.allow(anyString(), any())).thenAnswer(i -> allowedSoFar.incrementAndGet() <= 30);
        when(throttle.countOverflow(anyString(), anyString(), anyString())).thenAnswer(i -> {
            overflow.incrementAndGet();
            return true;
        });
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), any(RowMapper.class))).thenAnswer(i -> {
            sql.add(i.getArgument(0));
            int now = inflight.incrementAndGet();
            maxInflight.accumulateAndGet(now, Math::max);
            try {
                Thread.sleep(perWriteMs);
            } finally {
                inflight.decrementAndGet();
            }
            persisted.incrementAndGet();
            return state;
        });
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenAnswer(i -> {
            String q = i.getArgument(0);
            sql.add(q);
            return q.contains("status = 'NEW'") ? reopenUpdateCount : 1;
        });
        when(jdbc.update(anyString(), anyMap())).thenAnswer(i -> {
            sql.add(i.getArgument(0));
            return 1;
        });
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        service = new CrashService(jdbc, redis, Clock.fixed(NOW, ZoneOffset.UTC), mock(PlatformTransactionManager.class),
                throttle, mock(SchedulerLock.class), 50, 4);
    }

    private static ReportRequest report(String frame) {
        return new ReportRequest("2.0.5", "ANDROID", "14", "Pixel", "StateError", "boom",
                "#0 " + frame + " (package:bu_kampus/a.dart:1:1)", "Home", true, null);
    }

    private List<Throwable> storm(int threads, java.util.function.IntFunction<ReportRequest> req) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Throwable>> fs = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            final int n = i;
            fs.add(pool.submit(() -> {
                go.await();
                try {
                    service.record(req.apply(n));
                    return null;
                } catch (Throwable t) {
                    return t;
                }
            }));
        }
        go.countDown();
        List<Throwable> errors = new ArrayList<>();
        for (Future<Throwable> f : fs) {
            Throwable t = f.get(30, TimeUnit.SECONDS);
            if (t != null) {
                errors.add(t);
            }
        }
        pool.shutdownNow();
        return errors;
    }

    @Test
    void sameSignatureStormWritesAtMostThirtyRowsPerMinuteAndCountsTheRest() throws Exception {
        perWriteMs = 2; // CI yuku altinda 250 ms kapi beklemesi asilmasin
        List<Throwable> errors = storm(200, n -> report("same"));
        assertThat(errors).isEmpty();
        assertThat(persisted.get()).isBetween(1, 30);
        assertThat(overflow.get()).isEqualTo(170);
        assertThat(maxInflight.get()).isLessThanOrEqualTo(4);
    }

    @Test
    void distinctSignaturesNeverExceedTheWriteGateAndExcessIsDroppedSilently() throws Exception {
        when(throttle.allow(anyString(), any())).thenReturn(true);
        perWriteMs = 40;
        long t0 = System.nanoTime();
        List<Throwable> errors = storm(120, n -> report("frame" + n));
        long ms = (System.nanoTime() - t0) / 1_000_000;
        assertThat(errors).isEmpty();
        assertThat(maxInflight.get()).isLessThanOrEqualTo(4);
        assertThat(persisted.get()).isBetween(4, 120);
        // istek suresi sinirli: en kotu durumda kapi bekleme suresi + bir yazma (CI toleransi ile)
        assertThat(ms).isLessThan(10_000);
    }

    @Test
    void recordNeverUsesForUpdateAndReadsTheGroupWithOneUpsert() {
        service.record(report("x"));
        assertThat(sql).noneMatch(s -> s.toUpperCase().contains("FOR UPDATE"));
        assertThat(sql).anyMatch(s -> s.contains("ON CONFLICT (signature) DO UPDATE") && s.contains("RETURNING"));
    }

    @Test
    void trimRunsOnlyEveryNthEvent() {
        state = new CrashService.GroupState(7, "NEW", "2.0.5", null, null, 11, false);
        service.record(report("a"));
        assertThat(sql).noneMatch(s -> s.startsWith("DELETE FROM crash_event"));
        sql.clear();
        state = new CrashService.GroupState(7, "NEW", "2.0.5", null, null, 20, false);
        service.record(report("b"));
        assertThat(sql).anyMatch(s -> s.startsWith("DELETE FROM crash_event"));
    }

    @Test
    void resolvedGroupReopensOnNewerVersionOnlyWhenTheConditionalUpdateWins() {
        state = new CrashService.GroupState(7, "RESOLVED", "2.0.0", null, "2.0.0", 5, false);
        assertThat(service.record(report("r")).reopened()).isTrue();
        reopenUpdateCount = 0; // baska bir istek/yonetici gecisi onceden yapti
        assertThat(service.record(report("r2")).reopened()).isFalse();
    }

    @Test
    void newGroupIsReportedAsCreated() {
        state = new CrashService.GroupState(9, "NEW", "2.0.5", null, null, 1, true);
        CrashService.Outcome o = service.record(report("c"));
        assertThat(o.created()).isTrue();
        assertThat(o.groupId()).isEqualTo(9);
    }

    @Test
    @SuppressWarnings("unchecked")
    void flushAddsOverflowCountsAndRestoresOnFailure() {
        String sig = "a".repeat(64);
        when(throttle.takeOverflow(500)).thenReturn(Map.of(sig + "|2.0.5|ANDROID", 170L));
        when(jdbc.queryForList(anyString(), anyMap(), eq(Long.class))).thenReturn(List.of(7L));
        assertThat(service.flushOverflow()).isEqualTo(170);
        ArgumentCaptor<SqlParameterSource> p = ArgumentCaptor.forClass(SqlParameterSource.class);
        verify(jdbc, org.mockito.Mockito.atLeastOnce()).update(eq("UPDATE crash_group SET event_count = event_count + :n, "
                + "last_seen_at = :now WHERE id = :id"), p.capture());
        assertThat(p.getValue().getValue("n")).isEqualTo(170L);
        verify(throttle, never()).restore(anyString(), anyLong());

        // DB hatasinda sayac Redis'e geri konur
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenThrow(new RuntimeException("db"));
        assertThat(service.flushOverflow()).isZero();
        verify(throttle).restore(sig + "|2.0.5|ANDROID", 170L);
    }

    @Test
    void flushIgnoresGroupsDeletedByRetention() {
        when(throttle.takeOverflow(500)).thenReturn(Map.of("b".repeat(64) + "|2.0.5|IOS", 3L));
        when(jdbc.queryForList(anyString(), anyMap(), eq(Long.class))).thenReturn(List.of());
        assertThat(service.flushOverflow()).isEqualTo(3);
        verify(jdbc, never()).update(org.mockito.ArgumentMatchers.startsWith("UPDATE crash_group SET event_count"),
                any(SqlParameterSource.class));
    }
}
