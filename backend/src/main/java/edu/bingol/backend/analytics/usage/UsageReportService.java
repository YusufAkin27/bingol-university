package edu.bingol.backend.analytics.usage;

import edu.bingol.backend.analytics.DateRange;
import edu.bingol.backend.analytics.usage.UsageDtos.ActionItem;
import edu.bingol.backend.analytics.usage.UsageDtos.DayUsage;
import edu.bingol.backend.analytics.usage.UsageDtos.FeatureItem;
import edu.bingol.backend.analytics.usage.UsageDtos.Features;
import edu.bingol.backend.analytics.usage.UsageDtos.Flow;
import edu.bingol.backend.analytics.usage.UsageDtos.FlowEdge;
import edu.bingol.backend.analytics.usage.UsageDtos.HourCell;
import edu.bingol.backend.analytics.usage.UsageDtos.Hourly;
import edu.bingol.backend.analytics.usage.UsageDtos.Peak;
import edu.bingol.backend.analytics.usage.UsageDtos.ScreenItem;
import edu.bingol.backend.analytics.usage.UsageDtos.SegmentItem;
import edu.bingol.backend.analytics.usage.UsageDtos.Segments;
import edu.bingol.backend.analytics.usage.UsageDtos.Summary;
import edu.bingol.backend.analytics.usage.UsageDtos.TopActions;
import edu.bingol.backend.analytics.usage.UsageDtos.TopScreens;
import edu.bingol.backend.analytics.usage.UsageReportRepository.ActionRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.DayRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.Edge;
import edu.bingol.backend.analytics.usage.UsageReportRepository.FeatureRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.HourRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.KeyDay;
import edu.bingol.backend.analytics.usage.UsageReportRepository.ScreenRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.SegRow;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;

/**
 * Kullanim raporlari: tarih araligi dogrulamasi (DateRange, Europe/Istanbul) + gunluk ozet satirlarini sozlesmedeki
 * sekle cevirme. Sonuclar `usage` ad alaninda 5 dk onbelleklenir (yoneticiye ozel, herkese ayni veri).
 */
@Service
@Transactional(readOnly = true)
public class UsageReportService {

    static final int SCREEN_LIMIT = 20;
    static final int ACTION_LIMIT = 20;
    static final int EDGE_LIMIT = 30;
    /** Kirilim basina en cok gosterilen oge; fazlasi 'other' altinda birlesir. */
    static final int SEGMENT_TOP = 12;
    static final String OTHER = "other";

    private final UsageReportRepository repo;
    private final Clock clock;
    private CacheService cache = CacheService.passthrough();

    /** Faculty/department/version kirilimlarinda grup basina asgari kullanici (yazarken uygulanir; taban 5). */
    private final int k;

    public UsageReportService(UsageReportRepository repo, Clock clock,
                              @Value("${app.analytics.k-anonymity:10}") int k) {
        this.repo = repo;
        this.clock = clock;
        this.k = UsagePrivacy.effectiveK(k);
    }

    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
    }

    /** Yenilenen ozetlerden sonra eski onbellek sunulmasin. */
    public void invalidateCache() {
        cache.invalidate("usage");
    }

    private <T> T cached(String name, DateRange r, TypeReference<T> type, Supplier<T> loader) {
        return cache.getPositive("usage", name + ":" + r.from() + ":" + r.to(), CacheTier.SHORT, type, loader);
    }

    // --- ozet ---

    public Summary summary(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("summary", r, new TypeReference<Summary>() {}, () -> buildSummary(r));
    }

    private Summary buildSummary(DateRange r) {
        Map<LocalDate, DayRow> byDay = new HashMap<>();
        for (DayRow d : repo.days(r)) {
            byDay.put(d.day(), d);
        }
        List<DayUsage> daily = new ArrayList<>();
        long sessions = 0;
        long views = 0;
        long dauSum = 0;
        long usersSum = 0;
        long durSum = 0;
        long durN = 0;
        for (LocalDate d = r.from(); !d.isAfter(r.to()); d = d.plusDays(1)) {
            DayRow row = byDay.get(d);
            if (row == null) {
                daily.add(new DayUsage(d.toString(), 0, 0, 0, 0));
                continue;
            }
            daily.add(new DayUsage(d.toString(), row.dau(), row.reportingUsers(), row.sessions(), row.views()));
            sessions += row.sessions();
            views += row.views();
            dauSum += row.dau();
            usersSum += row.reportingUsers();
            durSum += row.durSum();
            durN += row.durN();
        }
        int withData = byDay.size();
        List<ScreenRow> top = repo.topScreens(r, 1);
        List<ActionRow> act = repo.topActions(r, 1);
        return new Summary(r.from().toString(), r.to().toString(), sessions, views,
                withData == 0 ? 0 : round1(dauSum / (double) withData),
                withData == 0 ? 0 : round1(usersSum / (double) withData),
                durN == 0 ? null : round1(durSum / (double) durN),
                top.isEmpty() ? null : top.get(0).screen(), act.isEmpty() ? null : act.get(0).action(), daily);
    }

    // --- ekranlar ---

    public TopScreens topScreens(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("top-screens", r, new TypeReference<TopScreens>() {}, () -> buildTopScreens(r));
    }

    private TopScreens buildTopScreens(DateRange r) {
        List<ScreenRow> rows = repo.topScreens(r, SCREEN_LIMIT);
        List<String> names = rows.stream().map(ScreenRow::screen).toList();
        Map<String, List<Long>> trend = trends(r, repo.screenTrend(r, names));
        Map<String, long[]> hist = repo.durationBuckets(r, names);
        int active = activeDays(r);
        List<ScreenItem> items = new ArrayList<>();
        for (ScreenRow s : rows) {
            long[] h = hist.get(s.screen());
            double med = h == null ? -1 : UsageBuckets.medianMs(h);
            items.add(new ScreenItem(s.screen(), s.views(), s.userDays(),
                    active == 0 ? 0 : round1(s.userDays() / (double) active),
                    s.durN() == 0 ? null : round1(s.durSumMs() / (double) s.durN() / 1000.0),
                    med < 0 ? null : round1(med / 1000.0),
                    percent(s.exits(), s.views()), trendOf(trend, s.screen(), r)));
        }
        return new TopScreens(r.from().toString(), r.to().toString(), dates(r), repo.totalViews(r), items);
    }

    /** Verisi olan gun sayisi (gunluk ortalama kullanici paydasi). */
    private int activeDays(DateRange r) {
        return repo.days(r).size();
    }

    // --- eylemler ---

    public TopActions topActions(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("top-actions", r, new TypeReference<TopActions>() {}, () -> buildTopActions(r));
    }

    private TopActions buildTopActions(DateRange r) {
        List<DayRow> days = repo.days(r);
        long reporting = days.stream().mapToLong(DayRow::reportingUsers).sum();
        List<ActionRow> rows = repo.topActions(r, ACTION_LIMIT);
        Map<String, List<Long>> trend = trends(r, repo.actionTrend(r, rows.stream().map(ActionRow::action).toList()));
        List<ActionItem> items = new ArrayList<>();
        for (ActionRow a : rows) {
            items.add(new ActionItem(a.action(), a.events(), a.userDays(), percent(a.userDays(), reporting),
                    trendOf(trend, a.action(), r)));
        }
        return new TopActions(r.from().toString(), r.to().toString(), dates(r), repo.totalActionEvents(r),
                days.isEmpty() ? 0 : round1(reporting / (double) days.size()), items);
    }

    // --- akis ---

    public Flow flow(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("flow", r, new TypeReference<Flow>() {}, () -> {
            List<FlowEdge> edges = repo.topEdges(r, EDGE_LIMIT).stream()
                    .map((Edge e) -> new FlowEdge(e.src(), e.dst(), e.n())).toList();
            return new Flow(r.from().toString(), r.to().toString(), repo.totalTransitions(r), edges);
        });
    }

    // --- saat x gun ---

    public Hourly hourly(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("hourly", r, new TypeReference<Hourly>() {}, () -> buildHourly(r));
    }

    private Hourly buildHourly(DateRange r) {
        long[][] sessions = new long[8][24];
        long[][] views = new long[8][24];
        for (HourRow h : repo.hourly(r)) {
            if (h.dow() >= 1 && h.dow() <= 7 && h.hour() >= 0 && h.hour() <= 23) {
                sessions[h.dow()][h.hour()] = h.sessions();
                views[h.dow()][h.hour()] = h.views();
            }
        }
        List<HourCell> cells = new ArrayList<>(168);
        long ts = 0;
        long tv = 0;
        Peak peak = null;
        for (int d = 1; d <= 7; d++) {
            for (int h = 0; h < 24; h++) {
                cells.add(new HourCell(d, h, sessions[d][h], views[d][h]));
                ts += sessions[d][h];
                tv += views[d][h];
                if (sessions[d][h] > 0 && (peak == null || sessions[d][h] > peak.sessions())) {
                    peak = new Peak(d, h, sessions[d][h]);
                }
            }
        }
        return new Hourly(r.from().toString(), r.to().toString(), ts, tv, peak, cells);
    }

    // --- kirilimlar ---

    public Segments segments(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("segments", r, new TypeReference<Segments>() {}, () -> buildSegments(r));
    }

    private Segments buildSegments(DateRange r) {
        Map<String, List<SegRow>> byKind = new LinkedHashMap<>();
        for (SegRow s : repo.segments(r)) {
            byKind.computeIfAbsent(s.kind(), x -> new ArrayList<>()).add(s);
        }
        return new Segments(r.from().toString(), r.to().toString(), k,
                segmentItems(byKind.get("platform"), false), segmentItems(byKind.get("version"), true),
                segmentItems(byKind.get("faculty"), true), segmentItems(byKind.get("department"), true));
    }

    /** Kullanici-gun toplamina gore azalan; ilk SEGMENT_TOP disi 'other' altinda birlesir ('other' hep sonda). */
    static List<SegmentItem> segmentItems(List<SegRow> rows, boolean fold) {
        if (rows == null || rows.isEmpty()) {
            return List.of();
        }
        long total = rows.stream().mapToLong(SegRow::users).sum();
        long other = 0;
        List<SegRow> named = new ArrayList<>();
        for (SegRow s : rows) {
            if (OTHER.equals(s.seg())) {
                other += s.users();
            } else {
                named.add(s);
            }
        }
        named.sort(Comparator.comparingLong(SegRow::users).reversed().thenComparing(SegRow::seg));
        List<SegmentItem> out = new ArrayList<>();
        for (int i = 0; i < named.size(); i++) {
            SegRow s = named.get(i);
            if (fold && i >= SEGMENT_TOP) {
                other += s.users();
            } else {
                out.add(new SegmentItem(s.seg(), s.users(), percent(s.users(), total)));
            }
        }
        if (other > 0) {
            out.add(new SegmentItem(OTHER, other, percent(other, total)));
        }
        return out;
    }

    // --- ozellik benimseme ---

    public Features features(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        return cached("features", r, new TypeReference<Features>() {}, () -> buildFeatures(r));
    }

    private Features buildFeatures(DateRange r) {
        List<FeatureRow> rows = repo.latestFeatures(r.to());
        if (rows.isEmpty()) {
            return new Features(null, 0, 0, List.of());
        }
        long mau = rows.get(0).mau();
        long reporting = 0;
        List<FeatureItem> items = new ArrayList<>();
        for (FeatureRow f : rows) {
            if (UsageFeatures.ALL.equals(f.feature())) {
                reporting = f.users();
            } else {
                items.add(new FeatureItem(f.feature(), f.users(), percent(f.users(), mau)));
            }
        }
        // bos ozellikler de listelenir (0 kullanici): panel tabloyu sabit sirayla gosterebilsin
        for (String feature : UsageFeatures.PREFIXES.keySet()) {
            if (items.stream().noneMatch(i -> i.feature().equals(feature))) {
                items.add(new FeatureItem(feature, 0, 0));
            }
        }
        items.sort(Comparator.comparingLong(FeatureItem::users).reversed().thenComparing(FeatureItem::feature));
        return new Features(rows.get(0).day().toString(), mau, reporting, items);
    }

    // --- yardimcilar ---

    static List<String> datesOf(DateRange r) {
        List<String> out = new ArrayList<>();
        for (LocalDate d = r.from(); !d.isAfter(r.to()); d = d.plusDays(1)) {
            out.add(d.toString());
        }
        return out;
    }

    private static List<String> dates(DateRange r) {
        return datesOf(r);
    }

    /** anahtar -> aralikla ayni uzunlukta gunluk dizi; verisi olmayan anahtar haritada yoktur ({@link #trendOf}). */
    private static Map<String, List<Long>> trends(DateRange r, List<KeyDay> rows) {
        int n = r.days();
        Map<String, long[]> tmp = new HashMap<>();
        for (KeyDay k : rows) {
            long idx = java.time.temporal.ChronoUnit.DAYS.between(r.from(), k.day());
            if (idx >= 0 && idx < n) {
                tmp.computeIfAbsent(k.key(), x -> new long[n])[(int) idx] = k.n();
            }
        }
        Map<String, List<Long>> out = new HashMap<>();
        tmp.forEach((key, arr) -> out.put(key, java.util.Arrays.stream(arr).boxed().toList()));
        return out;
    }

    private static List<Long> trendOf(Map<String, List<Long>> trend, String key, DateRange r) {
        List<Long> v = trend.get(key);
        return v != null ? v : java.util.Collections.nCopies(r.days(), 0L);
    }

    static double percent(long part, long total) {
        return total == 0 ? 0 : Math.round(part * 1000.0 / total) / 10.0;
    }

    static double round1(double v) {
        return Math.round(v * 10.0) / 10.0;
    }
}
