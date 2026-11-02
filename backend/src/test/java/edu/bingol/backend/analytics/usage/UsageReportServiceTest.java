package edu.bingol.backend.analytics.usage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.analytics.usage.UsageDtos.Features;
import edu.bingol.backend.analytics.usage.UsageDtos.Hourly;
import edu.bingol.backend.analytics.usage.UsageDtos.ScreenItem;
import edu.bingol.backend.analytics.usage.UsageDtos.SegmentItem;
import edu.bingol.backend.analytics.usage.UsageDtos.Summary;
import edu.bingol.backend.analytics.usage.UsageDtos.TopActions;
import edu.bingol.backend.analytics.usage.UsageDtos.TopScreens;
import edu.bingol.backend.analytics.usage.UsageReportRepository.ActionRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.DayRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.FeatureRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.HourRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.KeyDay;
import edu.bingol.backend.analytics.usage.UsageReportRepository.ScreenRow;
import edu.bingol.backend.analytics.usage.UsageReportRepository.SegRow;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class UsageReportServiceTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-11-02T09:00:00Z"), ZoneOffset.UTC);
    private static final String FROM = "2026-10-31";
    private static final String TO = "2026-11-02";

    private UsageReportRepository repo;
    private UsageReportService svc;

    @BeforeEach
    void setUp() {
        repo = mock(UsageReportRepository.class);
        svc = new UsageReportService(repo, CLOCK, 10);
    }

    private static LocalDate d(String s) {
        return LocalDate.parse(s);
    }

    @Test
    void topScreensComputesAveragesMedianExitAndTrend() {
        when(repo.topScreens(any(), anyInt())).thenReturn(List.of(
                new ScreenRow("home", 200, 120, 1_000_000, 100, 50),
                new ScreenRow("menu", 10, 5, 0, 0, 0)));
        when(repo.totalViews(any())).thenReturn(210L);
        when(repo.days(any())).thenReturn(List.of(new DayRow(d("2026-11-01"), 50, 40, 60, 100, 0, 0),
                new DayRow(d("2026-11-02"), 50, 40, 60, 100, 0, 0)));
        when(repo.screenTrend(any(), anyList())).thenReturn(List.of(new KeyDay("home", d("2026-11-01"), 120),
                new KeyDay("home", d("2026-11-02"), 80)));
        long[] h = new long[UsageBuckets.COUNT];
        h[3] = 10;
        when(repo.durationBuckets(any(), anyList())).thenReturn(Map.of("home", h));

        TopScreens r = svc.topScreens(FROM, TO);

        assertEquals(List.of("2026-10-31", "2026-11-01", "2026-11-02"), r.dates());
        assertEquals(210, r.totalViews());
        ScreenItem home = r.items().get(0);
        assertEquals("home", home.screen());
        assertEquals(10.0, home.avgSeconds());          // 1_000_000 ms / 100 / 1000
        assertEquals(7.5, home.medianSeconds());
        assertEquals(25.0, home.exitPercent());         // 50 / 200
        assertEquals(60.0, home.avgDailyUsers());       // 120 kullanici-gun / 2 gun
        assertEquals(List.of(0L, 120L, 80L), home.trend());
        ScreenItem menu = r.items().get(1);
        assertNull(menu.avgSeconds());
        assertNull(menu.medianSeconds());
        assertEquals(List.of(0L, 0L, 0L), menu.trend());
    }

    @Test
    void topScreensEmptyIsEmptyNotError() {
        when(repo.topScreens(any(), anyInt())).thenReturn(List.of());
        when(repo.days(any())).thenReturn(List.of());
        TopScreens r = svc.topScreens(FROM, TO);
        assertTrue(r.items().isEmpty());
        assertEquals(0, r.totalViews());
    }

    @Test
    void actionAdoptionIsActionUserDaysOverReportingUserDays() {
        when(repo.days(any())).thenReturn(List.of(new DayRow(d("2026-11-01"), 90, 80, 0, 0, 0, 0),
                new DayRow(d("2026-11-02"), 110, 120, 0, 0, 0, 0)));
        when(repo.topActions(any(), anyInt())).thenReturn(List.of(new ActionRow("news_open", 300, 50)));
        when(repo.totalActionEvents(any())).thenReturn(300L);
        when(repo.actionTrend(any(), anyList())).thenReturn(List.of());

        TopActions r = svc.topActions(FROM, TO);

        assertEquals(25.0, r.items().get(0).adoptionPercent()); // 50 / 200
        assertEquals(100.0, r.avgReportingUsers());
        assertEquals(3, r.items().get(0).trend().size());
    }

    @Test
    void hourlyAlwaysHas168CellsAndFindsPeak() {
        when(repo.hourly(any())).thenReturn(List.of(new HourRow(1, 9, 30, 100), new HourRow(5, 13, 70, 400),
                new HourRow(9, 1, 5, 5), new HourRow(2, 30, 5, 5)));
        Hourly r = svc.hourly(FROM, TO);
        assertEquals(168, r.cells().size());
        assertEquals(100, r.totalSessions());
        assertEquals(5, r.peak().dow());
        assertEquals(13, r.peak().hour());
    }

    @Test
    void segmentsFoldTailAndKeepOtherLast() {
        List<SegRow> rows = new ArrayList<>();
        for (int i = 0; i < 15; i++) {
            rows.add(new SegRow("faculty", String.format("F%02d", i), 100 - i, 0));
        }
        rows.add(new SegRow("faculty", "other", 20, 0));
        List<SegmentItem> items = UsageReportService.segmentItems(rows, true);
        assertEquals(UsageReportService.SEGMENT_TOP + 1, items.size());
        SegmentItem last = items.get(items.size() - 1);
        assertEquals("other", last.key());
        assertEquals(20 + 88 + 87 + 86, last.userDays());
        assertEquals(rows.stream().mapToLong(SegRow::users).sum(),
                items.stream().mapToLong(SegmentItem::userDays).sum());
    }

    @Test
    void platformsAreNotFolded() {
        List<SegmentItem> items = UsageReportService.segmentItems(List.of(new SegRow("platform", "android", 70, 0),
                new SegRow("platform", "ios", 30, 0)), false);
        assertEquals(2, items.size());
        assertEquals(70.0, items.get(0).percent());
    }

    @Test
    void segmentsReportEffectiveKFloor() {
        UsageReportService low = new UsageReportService(repo, CLOCK, 1);
        when(repo.segments(any())).thenReturn(List.of());
        assertEquals(UsagePrivacy.K_FLOOR, low.segments(FROM, TO).kAnonymity());
        assertEquals(10, svc.segments(FROM, TO).kAnonymity());
    }

    @Test
    void featuresListEveryFeatureAndPercentOfMau() {
        when(repo.latestFeatures(any())).thenReturn(List.of(
                new FeatureRow(d("2026-11-01"), "all", 800, 1000),
                new FeatureRow(d("2026-11-01"), "news", 500, 1000),
                new FeatureRow(d("2026-11-01"), "menu", 250, 1000)));
        Features r = svc.features(FROM, TO);
        assertEquals("2026-11-01", r.asOf());
        assertEquals(1000, r.mau());
        assertEquals(800, r.reportingUsers());
        assertEquals(UsageFeatures.PREFIXES.size(), r.items().size());
        assertEquals("news", r.items().get(0).feature());
        assertEquals(50.0, r.items().get(0).percentOfMau());
        assertEquals(0, r.items().get(r.items().size() - 1).users());
    }

    @Test
    void featuresWithoutSnapshotAreEmpty() {
        when(repo.latestFeatures(any())).thenReturn(List.of());
        Features r = svc.features(FROM, TO);
        assertNull(r.asOf());
        assertTrue(r.items().isEmpty());
    }

    @Test
    void summaryAveragesOnlyDaysWithData() {
        when(repo.days(any())).thenReturn(List.of(new DayRow(d("2026-11-01"), 100, 90, 300, 1500, 6000, 100),
                new DayRow(d("2026-11-02"), 120, 110, 360, 1800, 0, 0)));
        when(repo.topScreens(any(), eq(1))).thenReturn(List.of(new ScreenRow("home", 1, 1, 0, 0, 0)));
        when(repo.topActions(any(), eq(1))).thenReturn(List.of());
        Summary r = svc.summary(FROM, TO);
        assertEquals(660, r.totalSessions());
        assertEquals(110.0, r.avgDau());
        assertEquals(60.0, r.avgSessionSeconds());
        assertEquals("home", r.topScreen());
        assertNull(r.topAction());
        assertEquals(3, r.daily().size());
        assertEquals(0, r.daily().get(0).dau());
    }

    @Test
    void invalidRangeIs400() {
        ApiException ex = assertThrows(ApiException.class, () -> svc.flow("2026-11-05", "2026-11-01"));
        assertEquals("INVALID_RANGE", ex.code());
    }
}
