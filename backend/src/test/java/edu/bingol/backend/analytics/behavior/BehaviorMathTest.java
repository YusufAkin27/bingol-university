package edu.bingol.backend.analytics.behavior;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import edu.bingol.backend.analytics.behavior.BehaviorMath.Ev;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Session;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Summary;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Saf oturumlastirma / bounce / hemen kapatma / yuzdelik hesabi (SQL'den bagimsiz; SQL'in kendisi duman betiginde). */
class BehaviorMathTest {

    private static final Instant T0 = Instant.parse("2026-11-02T10:00:00Z");
    private static long ids = 0;

    private static Instant t(long sec) {
        return T0.plusSeconds(sec);
    }

    private static Ev ev(String name, String screen, String sid, long sec) {
        return new Ev(++ids, name, screen, sid, null, null, null, null, null, t(sec));
    }

    private static Ev view(String screen, String sid, long sec) {
        return ev("screen_view", screen, sid, sec);
    }

    private static Ev exit(String screen, String sid, long sec, long dwell) {
        return new Ev(++ids, "screen_exit", screen, sid, null, dwell, null, null, null, t(sec));
    }

    private static Ev end(String sid, long sec, long durationMs, int screens, String reason) {
        return new Ev(++ids, "session_end", null, sid, null, null, durationMs, screens, reason, t(sec));
    }

    private static Ev action(String screen, String sid, String kind, long sec) {
        return new Ev(++ids, "action", screen, sid, kind, null, null, null, null, t(sec));
    }

    @Test
    void sidSessionsAreSeparatedBySid() {
        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), view("news", "aaaaaaaa", 20),
                view("home", "bbbbbbbb", 5)));
        assertThat(s).hasSize(2);
        assertThat(s.get(0).sid()).isEqualTo("aaaaaaaa");
        assertThat(s.get(0).screens()).isEqualTo(2);
        assertThat(s.get(1).sid()).isEqualTo("bbbbbbbb");
    }

    @Test
    void sessionEndSuppliesDurationScreensAndReason() {
        List<Session> s = BehaviorMath.sessionize(List.of(
                ev("session_start", null, "aaaaaaaa", 0), view("home", "aaaaaaaa", 0),
                exit("home", "aaaaaaaa", 90, 90_000), end("aaaaaaaa", 90, 95_000, 1, "background")));
        assertThat(s).hasSize(1);
        Session x = s.get(0);
        assertThat(x.durationMs()).isEqualTo(95_000);
        assertThat(x.reason()).isEqualTo("background");
        assertThat(x.bounce()).isFalse(); // 1 ekran ama 95 sn
        assertThat(x.quickClose()).isFalse();
    }

    @Test
    void withoutSessionEndDurationIsDerivedFromSpanAndDwell() {
        // 3 olay arasi 60 sn; ekranda gecen toplam 100 sn (aralikta olay yok) -> en az dwell toplami
        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), exit("home", "aaaaaaaa", 60, 100_000)));
        assertThat(s.get(0).reason()).isEqualTo("derived");
        assertThat(s.get(0).durationMs()).isEqualTo(100_000);

        List<Session> s2 = BehaviorMath.sessionize(List.of(view("home", "cccccccc", 0), view("news", "cccccccc", 45)));
        assertThat(s2.get(0).durationMs()).isEqualTo(45_000);
    }

    @Test
    void bounceAndQuickCloseDefinitions() {
        assertThat(BehaviorMath.isBounce(1, 9_999)).isTrue();
        assertThat(BehaviorMath.isBounce(0, 0)).isTrue();
        assertThat(BehaviorMath.isBounce(1, 10_000)).isFalse(); // sure < 10 sn kati
        assertThat(BehaviorMath.isBounce(2, 3_000)).isFalse(); // 2 ekran bounce degil
        assertThat(BehaviorMath.isQuickClose(4_999)).isTrue();
        assertThat(BehaviorMath.isQuickClose(5_000)).isFalse();

        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), end("aaaaaaaa", 3, 3_000, 1, "background")));
        assertThat(s.get(0).bounce()).isTrue();
        assertThat(s.get(0).quickClose()).isTrue();
    }

    @Test
    void legacyEventsWithoutSidSplitOnThirtyMinuteGap() {
        List<Session> s = BehaviorMath.sessionize(List.of(
                ev("app_open", null, null, 0), view("home", null, 10), view("news", null, 600),
                // 30 dk + 1 sn bosluk -> yeni oturum
                view("home", null, 600 + 1801), view("menu", null, 600 + 1801 + 30)));
        assertThat(s).hasSize(2);
        assertThat(s.get(0).screens()).isEqualTo(2);
        assertThat(s.get(0).durationMs()).isEqualTo(600_000);
        assertThat(s.get(1).durationMs()).isEqualTo(30_000);
        assertThat(s.get(0).sid()).isNull();
        // tam 30 dk bosluk ayni oturum
        assertThat(BehaviorMath.sessionize(List.of(view("a", null, 0), view("b", null, 1800)))).hasSize(1);
    }

    @Test
    void sidAndLegacyEventsDoNotMix() {
        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), view("home", null, 5), view("news", null, 10)));
        assertThat(s).hasSize(2);
    }

    @Test
    void actionOnlyGroupIsDroppedAndActionDoesNotChangeTiming() {
        assertThat(BehaviorMath.sessionize(List.of(action("home", "aaaaaaaa", "like", 0)))).isEmpty();
        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), action("home", "aaaaaaaa", "like", 500), view("news", "aaaaaaaa", 20)));
        assertThat(s.get(0).durationMs()).isEqualTo(20_000);
        assertThat(s.get(0).steps()).hasSize(3);
        // sid'siz eylem oturumsuz sayilir
        assertThat(BehaviorMath.sessionize(List.of(view("a", null, 0), action("a", null, "like", 1))).get(0).steps()).hasSize(1);
    }

    @Test
    void stepsMergeDwellIntoMatchingScreenAndKeepOrder() {
        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), exit("home", "aaaaaaaa", 12, 12_000),
                view("news", "aaaaaaaa", 12), action("news", "aaaaaaaa", "bookmark", 15),
                exit("news", "aaaaaaaa", 40, 28_000)));
        List<BehaviorMath.Step> steps = s.get(0).steps();
        assertThat(steps).extracting(BehaviorMath.Step::type).containsExactly("screen", "screen", "action");
        assertThat(steps.get(0).dwellMs()).isEqualTo(12_000);
        assertThat(steps.get(1).dwellMs()).isEqualTo(28_000);
        assertThat(steps.get(2).kind()).isEqualTo("bookmark");
        assertThat(steps.get(2).dwellMs()).isNull();
    }

    @Test
    void unsortedInputIsHandledAndStepsAreCapped() {
        List<Ev> evs = new ArrayList<>();
        for (int i = 150; i >= 0; i--) { // ters sirada
            evs.add(view("s" + i, "aaaaaaaa", i));
        }
        Session s = BehaviorMath.sessionize(evs).get(0);
        assertThat(s.steps()).hasSize(BehaviorMath.MAX_STEPS);
        assertThat(s.steps().get(0).screen()).isEqualTo("s0");
        assertThat(s.screens()).isEqualTo(151);
    }

    @Test
    void invalidReasonBecomesDerived() {
        List<Session> s = BehaviorMath.sessionize(List.of(view("a", "aaaaaaaa", 0), end("aaaaaaaa", 1, 1_000, 1, "weird")));
        assertThat(s.get(0).reason()).isEqualTo("derived");
    }

    @Test
    void percentileMatchesLinearInterpolation() {
        assertThat(BehaviorMath.percentile(List.of(), 0.5)).isZero();
        assertThat(BehaviorMath.percentile(List.of(7L), 0.9)).isEqualTo(7.0);
        assertThat(BehaviorMath.percentile(List.of(10L, 20L, 30L, 40L), 0.5)).isEqualTo(25.0);
        assertThat(BehaviorMath.percentile(List.of(40L, 10L, 30L, 20L), 0.5)).isEqualTo(25.0); // sirasiz girdi
        // 11 deger 0..100: p90 = 90
        List<Long> v = new ArrayList<>();
        for (long i = 0; i <= 100; i += 10) {
            v.add(i);
        }
        assertThat(BehaviorMath.percentile(v, 0.9)).isCloseTo(90.0, within(1e-9));
        assertThat(BehaviorMath.percentile(List.of(1L, 2L, 3L, 4L, 5L), 0.9)).isCloseTo(4.6, within(1e-9));
        assertThat(BehaviorMath.percentile(List.of(1L, 2L), 5.0)).isEqualTo(2.0); // p kenetlenir
    }

    @Test
    void bucketsFollowEdges() {
        assertThat(BehaviorMath.bucketIndex(0)).isZero();
        assertThat(BehaviorMath.bucketIndex(4_999)).isZero();
        assertThat(BehaviorMath.bucketIndex(5_000)).isEqualTo(1);
        assertThat(BehaviorMath.bucketIndex(29_999)).isEqualTo(1);
        assertThat(BehaviorMath.bucketIndex(30_000)).isEqualTo(2);
        assertThat(BehaviorMath.bucketIndex(120_000)).isEqualTo(3);
        assertThat(BehaviorMath.bucketIndex(600_000)).isEqualTo(4);
        assertThat(BehaviorMath.BUCKET_LABELS).containsExactly("<5sn", "5-30sn", "30sn-2dk", "2-10dk", "10dk+");
    }

    @Test
    void summaryAggregatesSessions() {
        Summary empty = BehaviorMath.summarize(List.of());
        assertThat(empty.sessions()).isZero();
        assertThat(empty.lastSeenAt()).isNull();
        assertThat(empty.bounceRate()).isZero();

        List<Session> s = BehaviorMath.sessionize(List.of(
                view("home", "aaaaaaaa", 0), end("aaaaaaaa", 2, 2_000, 1, "background"),            // bounce + quick
                view("home", "bbbbbbbb", 100), view("news", "bbbbbbbb", 110), end("bbbbbbbb", 200, 100_000, 2, "exit")));
        Summary sum = BehaviorMath.summarize(s);
        assertThat(sum.sessions()).isEqualTo(2);
        assertThat(sum.totalMs()).isEqualTo(102_000);
        assertThat(sum.avgSessionMs()).isEqualTo(51_000);
        assertThat(sum.bounceRate()).isEqualTo(0.5);
        assertThat(sum.quickCloseCount()).isEqualTo(1);
        assertThat(sum.lastSeenAt()).isEqualTo(t(200));
    }
}
