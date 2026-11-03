package edu.bingol.backend.analytics.behavior;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Davranis analizinin saf (veritabani gerektirmeyen) hesaplari: oturumlastirma, bounce/hemen kapatma tanimlari,
 * yuzdelik, sure kovalari. Tanimlar TEK yerdedir: {@link BehaviorSql} ayni sabitleri SQL parametresi olarak kullanir.
 *
 * <p>Oturum: olayda {@code props.sid} varsa (kullanici, sid) ciftidir; yoksa (eski surum) kullanici basina olaylar arasi
 * {@link #GAP} (30 dk) bosluguyla turetilir. {@code session_end} varsa sure/ekran sayisi/neden istemciden gelir, yoksa
 * sure sunucuda turetilir (son olay - ilk olay, en az ekranda gecen sure toplami) ve neden {@code derived} olur.
 */
public final class BehaviorMath {

    /** Eski olaylarda iki olay arasi bu boslugu asarsa yeni oturum. */
    public static final Duration GAP = Duration.ofMinutes(30);
    /** bounce = en cok bu kadar ekran VE sure bu degerden kisa. */
    public static final int BOUNCE_MAX_SCREENS = 1;
    public static final long BOUNCE_MS = 10_000;
    /** Hemen kapatma = sure bu degerden kisa. */
    public static final long QUICK_CLOSE_MS = 5_000;
    /** Sure kovasi ust sinirlari (haric); son kova 10 dk ve uzeri. */
    public static final long[] BUCKET_EDGES_MS = {5_000, 30_000, 120_000, 600_000};
    public static final List<String> BUCKET_LABELS = List.of("<5sn", "5-30sn", "30sn-2dk", "2-10dk", "10dk+");

    public static final int MAX_SESSIONS = 50;
    public static final int MAX_STEPS = 100;

    /** Oturumu tanimlayan (cekirdek) olay adlari; yalniz bunlar oturum acar ve sureyi belirler. */
    public static final Set<String> CORE_NAMES = Set.of("session_start", "session_end", "screen_view", "screen_exit", "app_open");
    private static final Set<String> OPENING_NAMES = Set.of("session_start", "session_end", "screen_view", "app_open");
    private static final Set<String> END_REASONS = Set.of("background", "exit", "timeout");

    private BehaviorMath() {}

    /** Ham olay satiri (veritabani okumasindan). {@code at} UTC an; alanlar ilgisiz olaylarda null. */
    public record Ev(long id, String name, String screen, String sid, String kind, Long dwellMs, Long durationMs,
                     Integer screens, String reason, Instant at) {}

    /** Oturum adimi: ekran (type=screen, dwellMs olabilir) ya da eylem (type=action, kind dolu). */
    public record Step(String type, String screen, String kind, Long dwellMs, Instant at) {}

    public record Session(String sid, Instant startedAt, Instant endedAt, long durationMs, int screens,
                          boolean bounce, boolean quickClose, String reason, List<Step> steps) {}

    public record Summary(int sessions, long totalMs, long avgSessionMs, double bounceRate, int quickCloseCount,
                          Instant lastSeenAt) {}

    // --- tanimlar ---

    public static boolean isBounce(int screens, long durationMs) {
        return screens <= BOUNCE_MAX_SCREENS && durationMs < BOUNCE_MS;
    }

    public static boolean isQuickClose(long durationMs) {
        return durationMs < QUICK_CLOSE_MS;
    }

    /** Sure kovasi indeksi (BUCKET_LABELS ile ayni sira). */
    public static int bucketIndex(long durationMs) {
        for (int i = 0; i < BUCKET_EDGES_MS.length; i++) {
            if (durationMs < BUCKET_EDGES_MS[i]) {
                return i;
            }
        }
        return BUCKET_EDGES_MS.length;
    }

    public static double ratio(long part, long whole) {
        return whole <= 0 ? 0.0 : (double) part / whole;
    }

    /** Dogrusal aradegerlemeli yuzdelik (PostgreSQL percentile_cont ile ayni); bos liste 0. p 0..1. */
    public static double percentile(List<Long> values, double p) {
        if (values == null || values.isEmpty()) {
            return 0.0;
        }
        List<Long> s = new ArrayList<>(values);
        s.sort(Long::compare);
        if (s.size() == 1) {
            return s.get(0);
        }
        double rank = Math.max(0.0, Math.min(1.0, p)) * (s.size() - 1);
        int lo = (int) Math.floor(rank);
        int hi = (int) Math.ceil(rank);
        return s.get(lo) + (s.get(hi) - s.get(lo)) * (rank - lo);
    }

    // --- oturumlastirma ---

    /** Olaylari (herhangi sirada) oturumlara boler; sonuc baslangic anina gore artan. Cekirdek olayi olmayan grup atilir. */
    public static List<Session> sessionize(List<Ev> events) {
        List<Ev> sorted = new ArrayList<>(events);
        sorted.sort(Comparator.comparing(Ev::at).thenComparingLong(Ev::id));

        Map<String, List<Ev>> groups = new LinkedHashMap<>();
        Instant lastLegacy = null;
        int legacyNo = 0;
        for (Ev e : sorted) {
            if (e.sid() != null) {
                groups.computeIfAbsent("s:" + e.sid(), k -> new ArrayList<>()).add(e);
            } else if (CORE_NAMES.contains(e.name())) { // sid'siz eylem oturumsuz sayilir
                if (lastLegacy == null || Duration.between(lastLegacy, e.at()).compareTo(GAP) > 0) {
                    legacyNo++;
                }
                lastLegacy = e.at();
                groups.computeIfAbsent("d:" + legacyNo, k -> new ArrayList<>()).add(e);
            }
        }
        List<Session> out = new ArrayList<>();
        for (Map.Entry<String, List<Ev>> g : groups.entrySet()) {
            Session s = build(g.getKey().startsWith("s:") ? g.getKey().substring(2) : null, g.getValue());
            if (s != null) {
                out.add(s);
            }
        }
        out.sort(Comparator.comparing(Session::startedAt));
        return out;
    }

    private static Session build(String sid, List<Ev> evs) {
        boolean core = false;
        Instant first = null;
        Instant last = null;
        Ev end = null;
        long dwellSum = 0;
        int views = 0;
        for (Ev e : evs) {
            if (!CORE_NAMES.contains(e.name())) {
                continue; // eylem sureyi/oturum araligini etkilemez
            }
            core |= OPENING_NAMES.contains(e.name());
            first = first == null ? e.at() : first;
            last = e.at();
            if (e.name().equals("session_end")) {
                end = e;
            } else if (e.name().equals("screen_exit") && e.dwellMs() != null) {
                dwellSum += e.dwellMs();
            } else if (e.name().equals("screen_view")) {
                views++;
            }
        }
        if (!core || first == null) {
            return null;
        }
        int screens = end != null && end.screens() != null ? end.screens() : views;
        long duration = end != null && end.durationMs() != null ? end.durationMs()
                : Math.max(Duration.between(first, last).toMillis(), dwellSum);
        String reason = end != null && end.reason() != null && END_REASONS.contains(end.reason()) ? end.reason() : "derived";
        return new Session(sid, first, last, duration, screens, isBounce(screens, duration), isQuickClose(duration),
                reason, steps(evs));
    }

    /** Adimlar kronolojik; screen_exit onceki acik ayni ekran adimina sure olarak islenir. En cok MAX_STEPS adim. */
    private static List<Step> steps(List<Ev> evs) {
        List<Step> steps = new ArrayList<>();
        for (Ev e : evs) {
            switch (e.name()) {
                case "screen_view" -> steps.add(new Step("screen", e.screen(), null, null, e.at()));
                case "action" -> steps.add(new Step("action", e.screen(), e.kind(), null, e.at()));
                case "screen_exit" -> {
                    for (int i = steps.size() - 1; i >= 0; i--) {
                        Step s = steps.get(i);
                        if (s.type().equals("screen") && s.dwellMs() == null && s.screen() != null
                                && s.screen().equals(e.screen())) {
                            steps.set(i, new Step("screen", s.screen(), null, e.dwellMs(), s.at()));
                            break;
                        }
                    }
                }
                default -> { }
            }
        }
        return steps.size() > MAX_STEPS ? new ArrayList<>(steps.subList(0, MAX_STEPS)) : steps;
    }

    public static Summary summarize(List<Session> sessions) {
        long total = 0;
        int bounces = 0;
        int quick = 0;
        Instant lastSeen = null;
        for (Session s : sessions) {
            total += s.durationMs();
            bounces += s.bounce() ? 1 : 0;
            quick += s.quickClose() ? 1 : 0;
            if (lastSeen == null || s.endedAt().isAfter(lastSeen)) {
                lastSeen = s.endedAt();
            }
        }
        int n = sessions.size();
        return new Summary(n, total, n == 0 ? 0 : Math.round((double) total / n), ratio(bounces, n), quick, lastSeen);
    }
}
