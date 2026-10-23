package edu.bingol.backend.analytics;

import edu.bingol.backend.analytics.ReportDtos.ActiveUsersReport;
import edu.bingol.backend.analytics.ReportDtos.Breakdown;
import edu.bingol.backend.analytics.ReportDtos.BreakdownItem;
import edu.bingol.backend.analytics.ReportDtos.Cohort;
import edu.bingol.backend.analytics.ReportDtos.ContentDay;
import edu.bingol.backend.analytics.ReportDtos.ContentReport;
import edu.bingol.backend.analytics.ReportDtos.DauPoint;
import edu.bingol.backend.analytics.ReportDtos.Engagement;
import edu.bingol.backend.analytics.ReportDtos.EngagementDay;
import edu.bingol.backend.analytics.ReportDtos.KeyCount;
import edu.bingol.backend.analytics.ReportDtos.Overview;
import edu.bingol.backend.analytics.ReportDtos.PushReport;
import edu.bingol.backend.analytics.ReportDtos.PushTotals;
import edu.bingol.backend.analytics.ReportDtos.RegistrationPoint;
import edu.bingol.backend.analytics.ReportDtos.Registrations;
import edu.bingol.backend.analytics.ReportDtos.Retention;
import edu.bingol.backend.analytics.ReportDtos.SupportReport;
import edu.bingol.backend.analytics.ReportDtos.TicketCounts;
import edu.bingol.backend.analytics.AnalyticsReportRepository.DayCount;
import edu.bingol.backend.analytics.AnalyticsReportRepository.Dimension;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.campaign.CampaignService;
import edu.bingol.backend.status.StatusService;
import edu.bingol.backend.status.dto.SourceStatus;
import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici raporlari: tarih araligi dogrulamasi + sorgu sonuclarini sozlesmedeki sekle cevirme. */
@Service
@Transactional(readOnly = true)
public class AnalyticsReportService {

    /** Dagilimda en cok gosterilen oge; fazlasi "other" altinda toplanir. */
    static final int MAX_BREAKDOWN_ITEMS = 50;
    static final String UNKNOWN = "unknown";
    static final String OTHER = "other";

    private final AnalyticsReportRepository repo;
    private final Clock clock;
    private final StatusService status;
    private final CampaignService campaigns;
    private final I18n i18n;

    public AnalyticsReportService(AnalyticsReportRepository repo, Clock clock, StatusService status, CampaignService campaigns, I18n i18n) {
        this.repo = repo;
        this.clock = clock;
        this.status = status;
        this.campaigns = campaigns;
        this.i18n = i18n;
    }

    public Overview overview() {
        return repo.overview(DateRange.today(clock));
    }

    public Registrations registrations(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        long cumulative = repo.registeredBefore(r);
        List<RegistrationPoint> points = new ArrayList<>();
        for (DayCount d : repo.registrationsPerDay(r)) {
            cumulative += d.n();
            points.add(new RegistrationPoint(d.day().toString(), d.n(), cumulative));
        }
        return new Registrations(points);
    }

    public ActiveUsersReport activeUsers(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        List<DauPoint> points = repo.dauPerDay(r).stream().map(d -> new DauPoint(d.day().toString(), d.n())).toList();
        return new ActiveUsersReport(points, repo.distinctActive(r.to().minusDays(6), r.to()),
                repo.distinctActive(r.to().minusDays(29), r.to()));
    }

    public Breakdown breakdown(String dimension) {
        Dimension d = Dimension.parse(dimension);
        if (d == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz boyut.");
        }
        return buildBreakdown(d.param, repo.breakdown(d), i18n.current("analytics.unknown"), i18n.current("analytics.other"));
    }

    /** Bos anahtarlar "unknown" altinda birlesir; ilk 50 oge sonrasi "other"; yuzdeler tek ondalik. */
    static Breakdown buildBreakdown(String dimension, List<KeyCount> rows, String unknownLabel, String otherLabel) {
        long total = rows.stream().mapToLong(KeyCount::count).sum();
        long unknown = 0;
        List<KeyCount> named = new ArrayList<>();
        for (KeyCount k : rows) {
            if (k.key() == null || k.key().isBlank()) {
                unknown += k.count();
            } else {
                named.add(k);
            }
        }
        if (unknown > 0) {
            named.add(new KeyCount(UNKNOWN, unknown));
        }
        named.sort((a, b) -> a.count() != b.count() ? Long.compare(b.count(), a.count()) : a.key().compareTo(b.key()));
        List<BreakdownItem> items = new ArrayList<>();
        long other = 0;
        for (int i = 0; i < named.size(); i++) {
            KeyCount k = named.get(i);
            if (i < MAX_BREAKDOWN_ITEMS) {
                items.add(new BreakdownItem(k.key(), k.key().equals(UNKNOWN) ? unknownLabel : k.key(), k.count(),
                        percent(k.count(), total)));
            } else {
                other += k.count();
            }
        }
        if (other > 0) {
            items.add(new BreakdownItem(OTHER, otherLabel, other, percent(other, total)));
        }
        return new Breakdown(dimension, total, items);
    }

    static double percent(long part, long total) {
        return total == 0 ? 0 : Math.round(part * 1000.0 / total) / 10.0;
    }

    public Engagement engagement(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        List<DayCount> msg = repo.messagesPerDay(r);
        List<DayCount> posts = repo.postsPerDay(r);
        List<DayCount> rsvps = repo.rsvpsPerDay(r);
        List<DayCount> searches = repo.searchesPerDay(r);
        List<EngagementDay> daily = new ArrayList<>();
        for (int i = 0; i < msg.size(); i++) {
            daily.add(new EngagementDay(msg.get(i).day().toString(), msg.get(i).n(), posts.get(i).n(),
                    rsvps.get(i).n(), searches.get(i).n()));
        }
        return new Engagement(repo.topEvents(r, 20), repo.screenViews(r, 20), daily, repo.funnel(r));
    }

    public Retention retention() {
        List<Cohort> cohorts = repo.cohorts(DateRange.today(clock)).stream()
                .map(c -> new Cohort(c.weekStart().toString(), c.size(), percent(c.a1(), c.e1()),
                        percent(c.a7(), c.e7()), percent(c.a30(), c.e30())))
                .toList();
        return new Retention(cohorts);
    }

    public SupportReport support() {
        Map<String, Long> t = repo.ticketCounts();
        return new SupportReport(new TicketCounts(t.getOrDefault("OPEN", 0L), t.getOrDefault("ANSWERED", 0L),
                t.getOrDefault("CLOSED", 0L)), repo.avgFirstResponseMinutes(), repo.feedbackBy("category"),
                repo.feedbackBy("status"));
    }

    public PushReport push() {
        long[] totals = repo.pushTotals();
        return new PushReport(new PushTotals(totals[0], totals[1]), campaigns.list(null, 10).items());
    }

    public ContentReport content(String from, String to) {
        DateRange r = DateRange.parse(from, to, clock);
        List<DayCount> news = repo.contentPerDay(r, "HABER");
        List<DayCount> ann = repo.contentPerDay(r, "DUYURU");
        List<DayCount> ev = repo.contentPerDay(r, "ETKINLIK");
        List<ContentDay> daily = new ArrayList<>();
        for (int i = 0; i < news.size(); i++) {
            daily.add(new ContentDay(news.get(i).day().toString(), news.get(i).n(), ann.get(i).n(), ev.get(i).n()));
        }
        Map<String, SourceStatus> sources = new LinkedHashMap<>();
        status.all().forEach(s -> sources.put(s.getSource(), SourceStatus.of(s)));
        return new ContentReport(daily, sources);
    }

    /** Testler icin: bugun (Istanbul). */
    LocalDate today() {
        return DateRange.today(clock);
    }
}
