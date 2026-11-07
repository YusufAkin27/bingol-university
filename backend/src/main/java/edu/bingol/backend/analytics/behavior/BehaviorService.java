package edu.bingol.backend.analytics.behavior;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.analytics.AnalyticsConfig;
import edu.bingol.backend.analytics.DateRange;
import edu.bingol.backend.analytics.EventContract;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.ActionStat;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Actions;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Bucket;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.DayStat;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.DropOff;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Flows;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Overview;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.ScreenCount;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.ScreenSessions;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.ScreensPage;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.SessionOut;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.StepOut;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Transition;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserDetail;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserInfo;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserRow;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserSummary;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UsersPage;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Session;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Summary;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.FlowRow;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.KindRow;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.KindScreenRow;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.OverviewRow;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Kullanici davranis analizi: aralik/parametre dogrulama, sorgu sonuclarini sozlesme DTO'larina cevirme. */
@Service
public class BehaviorService {

    /** Ham olay saklama suresiyle ayni: aralik en cok bu kadar gun. */
    public static final int MAX_DAYS = AnalyticsConfig.EVENT_RETENTION_DAYS;
    static final int DEFAULT_DAYS = 7;
    static final int MAX_PAGE_SIZE = 100;

    /** Izinli eylem turleri (EventContract ile ayni kaynak; sorgu beyaz listesi, sirali). */
    static final List<String> ACTION_KINDS = EventContract.ACTION_KINDS.stream().sorted().toList();

    private static final Map<String, String> SCREEN_SORT = Map.of("views", "v.views", "users", "v.uniq",
            "avgDwellMs", "avg_dwell", "exitRate", "exit_rate", "bounceRate", "bounce_rate");
    private static final Map<String, String> USER_SORT = Map.of("sessions", "a.sessions", "totalMs", "a.total_ms",
            "avgSessionMs", "a.avg_ms", "bounceRate", "a.bounce_rate", "quickCloseCount", "a.quick_count",
            "lastSeenAt", "a.last_seen");

    private final BehaviorRepository repo;
    private final Clock clock;

    public BehaviorService(BehaviorRepository repo, Clock clock) {
        this.repo = repo;
        this.clock = clock;
    }

    // --- aralik ---

    /** from/to yyyy-MM-dd (Istanbul gunu); bos: son 7 gun. 45 gunden uzun aralik: 400 RANGE_TOO_LARGE. */
    DateRange range(String from, String to) {
        return range(from, to, clock);
    }

    static DateRange range(String from, String to, Clock clock) {
        LocalDate t = to == null || to.isBlank() ? DateRange.today(clock) : parseDay(to);
        LocalDate f = from == null || from.isBlank() ? t.minusDays(DEFAULT_DAYS - 1L) : parseDay(from);
        if (f.isAfter(t)) {
            throw invalidRange();
        }
        if (ChronoUnit.DAYS.between(f, t) + 1 > MAX_DAYS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RANGE_TOO_LARGE",
                    "Tarih aralığı çok geniş (en çok " + MAX_DAYS + " gün).", String.valueOf(MAX_DAYS));
        }
        return new DateRange(f, t);
    }

    private static LocalDate parseDay(String s) {
        try {
            return LocalDate.parse(s.trim());
        } catch (DateTimeException e) {
            throw invalidRange();
        }
    }

    private static ApiException invalidRange() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_RANGE",
                "Geçersiz tarih aralığı (yyyy-MM-dd).", String.valueOf(MAX_DAYS));
    }

    // --- ozet ---

    public Overview overview(String from, String to) {
        DateRange r = range(from, to);
        return assembleOverview(repo.overview(r.startUtc(), r.endUtc()), r);
    }

    /** Saf birlestirme (birim testli): eksik gunler 0, kovalar tam ve etiketli. */
    static Overview assembleOverview(List<OverviewRow> rows, DateRange r) {
        OverviewRow total = rows.stream().filter(x -> x.kind().equals("total")).findFirst().orElse(null);
        Map<LocalDate, OverviewRow> byDay = new LinkedHashMap<>();
        long[] buckets = new long[BehaviorMath.BUCKET_LABELS.size()];
        for (OverviewRow x : rows) {
            if (x.kind().equals("day") && x.day() != null) {
                byDay.put(x.day(), x);
            } else if (x.kind().equals("bucket") && x.idx() >= 0 && x.idx() < buckets.length) {
                buckets[x.idx()] = x.n();
            }
        }
        List<DayStat> days = new ArrayList<>();
        for (LocalDate d = r.from(); !d.isAfter(r.to()); d = d.plusDays(1)) {
            OverviewRow x = byDay.get(d);
            days.add(x == null ? new DayStat(d.toString(), 0, 0, 0.0)
                    : new DayStat(d.toString(), (int) x.n(), Math.round(x.avgMs()), BehaviorMath.ratio(x.bounces(), x.n())));
        }
        List<Bucket> bs = new ArrayList<>();
        for (int i = 0; i < buckets.length; i++) {
            bs.add(new Bucket(BehaviorMath.BUCKET_LABELS.get(i), (int) buckets[i]));
        }
        if (total == null || total.n() == 0) {
            return new Overview(0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, days, bs);
        }
        return new Overview((int) total.n(), (int) total.users(), Math.round(total.avgMs()), Math.round(total.medMs()),
                total.avgScreens(), BehaviorMath.ratio(total.n(), total.users()),
                BehaviorMath.ratio(total.bounces(), total.n()), BehaviorMath.ratio(total.quicks(), total.n()), days, bs);
    }

    // --- ekranlar ---

    public ScreensPage screens(String from, String to, String sort, String dir, int page, int size) {
        DateRange r = range(from, to);
        String col = SCREEN_SORT.get(sort == null || sort.isBlank() ? "views" : sort);
        if (col == null) {
            throw badParam("sort");
        }
        int p = page(page);
        int s = size(size);
        BehaviorRepository.ScreenPageRow row = repo.screens(r.startUtc(), r.endUtc(), col, dir(dir), p, s);
        return new ScreensPage(row.items(), p, s, row.total());
    }

    // --- akislar ---

    public Flows flows(String from, String to) {
        DateRange r = range(from, to);
        return assembleFlows(repo.flows(r.startUtc(), r.endUtc()));
    }

    static Flows assembleFlows(List<FlowRow> rows) {
        List<Transition> transitions = new ArrayList<>();
        List<ScreenSessions> entries = new ArrayList<>();
        List<ScreenSessions> exits = new ArrayList<>();
        List<DropOff> drops = new ArrayList<>();
        for (FlowRow x : rows) {
            switch (x.kind()) {
                case "T" -> transitions.add(new Transition(x.a(), x.b(), (int) x.n()));
                case "E" -> entries.add(new ScreenSessions(x.a(), (int) x.n()));
                case "X" -> exits.add(new ScreenSessions(x.a(), (int) x.n()));
                case "D" -> drops.add(new DropOff(x.a(), (int) x.n(), (int) x.m(), BehaviorMath.ratio(x.m(), x.n())));
                default -> { }
            }
        }
        transitions.sort(Comparator.comparingInt(Transition::count).reversed().thenComparing(Transition::from)
                .thenComparing(Transition::to));
        entries.sort(Comparator.comparingInt(ScreenSessions::sessions).reversed().thenComparing(ScreenSessions::screen));
        exits.sort(Comparator.comparingInt(ScreenSessions::sessions).reversed().thenComparing(ScreenSessions::screen));
        drops.sort(Comparator.comparingInt(DropOff::left).reversed().thenComparing(DropOff::screen));
        return new Flows(transitions, entries, exits, drops);
    }

    // --- eylemler ---

    public Actions actions(String from, String to) {
        DateRange r = range(from, to);
        List<KindRow> kinds = repo.actionKinds(r.startUtc(), r.endUtc(), ACTION_KINDS);
        List<KindScreenRow> screens = repo.actionScreens(r.startUtc(), r.endUtc(), ACTION_KINDS);
        return assembleActions(kinds, screens);
    }

    static Actions assembleActions(List<KindRow> kinds, List<KindScreenRow> screens) {
        Map<String, List<ScreenCount>> per = new LinkedHashMap<>();
        screens.stream().filter(s -> !s.screen().isEmpty())
                .sorted(Comparator.comparingLong(KindScreenRow::n).reversed().thenComparing(KindScreenRow::screen))
                .forEach(s -> per.computeIfAbsent(s.kind(), k -> new ArrayList<>()).add(new ScreenCount(s.screen(), (int) s.n())));
        List<ActionStat> items = new ArrayList<>();
        for (KindRow k : kinds) {
            List<ScreenCount> top = per.getOrDefault(k.kind(), List.of());
            items.add(new ActionStat(k.kind(), (int) k.n(), (int) k.users(),
                    top.size() > 5 ? new ArrayList<>(top.subList(0, 5)) : top));
        }
        items.sort(Comparator.comparingInt(ActionStat::count).reversed().thenComparing(ActionStat::kind));
        return new Actions(items);
    }

    // --- kullanicilar ---

    public UsersPage users(String from, String to, String sort, String dir, String q, int page, int size) {
        DateRange r = range(from, to);
        String col = USER_SORT.get(sort == null || sort.isBlank() ? "sessions" : sort);
        if (col == null) {
            throw badParam("sort");
        }
        String term = q == null ? "" : q.trim();
        if (term.length() > 100) {
            term = term.substring(0, 100);
        }
        String like = term.isEmpty() ? null : "%" + escapeLike(term) + "%";
        String where = like == null ? "TRUE"
                : "(u.display_name ILIKE :q ESCAPE '\\' OR u.email ILIKE :q ESCAPE '\\')";
        int p = page(page);
        int s = size(size);
        BehaviorRepository.UsersPageResult res = repo.users(r.startUtc(), r.endUtc(), where, col, dir(dir), like, p, s);
        var tops = repo.topScreens(r.startUtc(), r.endUtc(), res.rows().stream().map(BehaviorRepository.UserPageRow::userId).toList());
        List<UserRow> items = res.rows().stream().map(u -> new UserRow(u.userId(), u.displayName(),
                PermissionAwareMasking.email(u.email()), u.department(), u.grade(), u.sessions(), u.totalMs(),
                u.avgMs(), u.bounceRate(), u.quickCount(), u.lastSeen(), tops.getOrDefault(u.userId(), List.of()))).toList();
        return new UsersPage(items, p, s, res.total());
    }

    /** Tek kullanici: son `days` gun (en cok 45), oturum + adim zaman cizelgesi. Denetim kaydina hedef kullanici yazilir. */
    public UserDetail userDetail(long userId, Integer days) {
        int d = days == null ? DEFAULT_DAYS : days;
        if (d < 1 || d > MAX_DAYS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RANGE_TOO_LARGE",
                    "Tarih aralığı çok geniş (en çok " + MAX_DAYS + " gün).", String.valueOf(MAX_DAYS));
        }
        UserInfo info = repo.userInfo(userId).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        AuditContext.target("USER", userId).summary("kullanici davranis zaman cizelgesi: " + d + " gun");
        LocalDate today = DateRange.today(clock);
        DateRange r = new DateRange(today.minusDays(d - 1L), today);
        List<Session> all = BehaviorMath.sessionize(repo.userEvents(userId, r.startUtc(), r.endUtc()));
        Summary sum = BehaviorMath.summarize(all);
        List<SessionOut> out = new ArrayList<>();
        for (int i = all.size() - 1; i >= 0 && out.size() < BehaviorMath.MAX_SESSIONS; i--) { // en yeni once
            Session s = all.get(i);
            out.add(new SessionOut(s.sid() == null ? "derived-" + s.startedAt().getEpochSecond() : s.sid(),
                    s.startedAt(), s.endedAt(), s.durationMs(), s.bounce(), s.quickClose(), s.reason(),
                    s.steps().stream().map(x -> new StepOut(x.type(), x.screen(), x.kind(), x.dwellMs(), x.at())).toList()));
        }
        return new UserDetail(new UserInfo(info.userId(), info.displayName(), PermissionAwareMasking.email(info.email()),
                info.department(), info.grade()),
                new UserSummary(sum.sessions(), sum.totalMs(), sum.avgSessionMs(), sum.bounceRate(),
                        sum.quickCloseCount(), sum.lastSeenAt()), out);
    }

    // --- yardimcilar ---

    private static int page(int page) {
        return Math.max(0, page);
    }

    private static int size(int size) {
        return size <= 0 ? 20 : Math.min(size, MAX_PAGE_SIZE);
    }

    /** Yon beyaz listesi: yalniz asc/desc (varsayilan desc). */
    private static String dir(String dir) {
        return "asc".equalsIgnoreCase(dir) ? "ASC" : "DESC";
    }

    private static ApiException badParam(String name) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz " + name + ".");
    }

    /** LIKE ozel karakterlerini (\, %, _) kacirir (ESCAPE '\'). */
    static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
