package edu.bingol.backend.analytics.behavior;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import edu.bingol.backend.analytics.DateRange;
import edu.bingol.backend.analytics.EventContract;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Actions;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Flows;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Overview;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.FlowRow;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.KindRow;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.KindScreenRow;
import edu.bingol.backend.analytics.behavior.BehaviorRepository.OverviewRow;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Aralik dogrulama ve sorgu sonucu birlestirme (veritabani gerektirmeyen kisim). */
class BehaviorServiceTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-11-02T09:00:00Z"), ZoneOffset.UTC);

    @Test
    void defaultRangeIsLastSevenDaysInIstanbul() {
        DateRange r = BehaviorService.range(null, null, CLOCK);
        assertThat(r.to()).isEqualTo(LocalDate.parse("2026-11-02"));
        assertThat(r.from()).isEqualTo(LocalDate.parse("2026-10-27"));
        assertThat(r.days()).isEqualTo(7);
        // yalniz to verilirse onceki 7 gun
        assertThat(BehaviorService.range(null, "2026-10-10", CLOCK).from()).isEqualTo(LocalDate.parse("2026-10-04"));
    }

    @Test
    void rangeUpTo45DaysAllowedBeyondIsRangeTooLarge() {
        assertThat(BehaviorService.range("2026-09-19", "2026-11-02", CLOCK).days()).isEqualTo(45);
        assertThatThrownBy(() -> BehaviorService.range("2026-09-18", "2026-11-02", CLOCK))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.code()).isEqualTo("RANGE_TOO_LARGE");
                    assertThat(e.status().value()).isEqualTo(400);
                });
    }

    @Test
    void malformedOrReversedRangeIsInvalidRange() {
        assertThatThrownBy(() -> BehaviorService.range("not-a-date", null, CLOCK))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("INVALID_RANGE"));
        assertThatThrownBy(() -> BehaviorService.range("2026-11-02", "2026-11-01", CLOCK))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("INVALID_RANGE"));
    }

    @Test
    void overviewFillsMissingDaysAndBuckets() {
        DateRange r = new DateRange(LocalDate.parse("2026-11-01"), LocalDate.parse("2026-11-03"));
        List<OverviewRow> rows = List.of(
                new OverviewRow("total", null, 0, 10, 4, 61_000.4, 30_000.2, 3.5, 2, 1),
                new OverviewRow("day", LocalDate.parse("2026-11-01"), 0, 6, 0, 50_000, 0, 0, 3, 0),
                new OverviewRow("day", LocalDate.parse("2026-11-03"), 0, 4, 0, 80_000.6, 0, 0, 1, 0),
                new OverviewRow("bucket", null, 0, 1, 0, 0, 0, 0, 0, 0),
                new OverviewRow("bucket", null, 4, 2, 0, 0, 0, 0, 0, 0));
        Overview o = BehaviorService.assembleOverview(rows, r);
        assertThat(o.sessions()).isEqualTo(10);
        assertThat(o.users()).isEqualTo(4);
        assertThat(o.avgSessionMs()).isEqualTo(61_000);
        assertThat(o.medianSessionMs()).isEqualTo(30_000);
        assertThat(o.sessionsPerUser()).isEqualTo(2.5);
        assertThat(o.bounceRate()).isEqualTo(0.2);
        assertThat(o.quickCloseRate()).isEqualTo(0.1);
        assertThat(o.byDay()).extracting(d -> d.day()).containsExactly("2026-11-01", "2026-11-02", "2026-11-03");
        assertThat(o.byDay().get(0).bounceRate()).isEqualTo(0.5);
        assertThat(o.byDay().get(1).sessions()).isZero();
        assertThat(o.byDay().get(2).avgSessionMs()).isEqualTo(80_001);
        assertThat(o.durationBuckets()).extracting(b -> b.label())
                .containsExactly("<5sn", "5-30sn", "30sn-2dk", "2-10dk", "10dk+");
        assertThat(o.durationBuckets()).extracting(b -> b.sessions()).containsExactly(1, 0, 0, 0, 2);
    }

    @Test
    void overviewOfEmptyRangeIsZeros() {
        DateRange r = new DateRange(LocalDate.parse("2026-11-01"), LocalDate.parse("2026-11-02"));
        Overview o = BehaviorService.assembleOverview(List.of(), r);
        assertThat(o.sessions()).isZero();
        assertThat(o.byDay()).hasSize(2);
        assertThat(o.durationBuckets()).hasSize(5);
        assertThat(o.bounceRate()).isZero();
    }

    @Test
    void flowsAreAssembledAndOrdered() {
        Flows f = BehaviorService.assembleFlows(List.of(
                new FlowRow("T", "home", "news", 5, 0), new FlowRow("T", "home", "menu", 9, 0),
                new FlowRow("E", "home", null, 12, 0), new FlowRow("X", "menu", null, 3, 0), new FlowRow("X", "news", null, 7, 0),
                new FlowRow("D", "news", null, 20, 5), new FlowRow("D", "menu", null, 4, 4)));
        assertThat(f.topTransitions()).extracting(t -> t.to()).containsExactly("menu", "news");
        assertThat(f.entryScreens().get(0).sessions()).isEqualTo(12);
        assertThat(f.exitScreens()).extracting(s -> s.screen()).containsExactly("news", "menu");
        assertThat(f.dropOff().get(0).screen()).isEqualTo("news");
        assertThat(f.dropOff().get(0).leftRate()).isEqualTo(0.25);
        assertThat(f.dropOff().get(1).leftRate()).isEqualTo(1.0);
    }

    @Test
    void actionsKeepTopFiveScreensEach() {
        List<KindScreenRow> screens = new java.util.ArrayList<>();
        for (int i = 1; i <= 7; i++) {
            screens.add(new KindScreenRow("like", "s" + i, i));
        }
        screens.add(new KindScreenRow("like", "", 100)); // ekransiz satir perScreen'e girmez
        screens.add(new KindScreenRow("follow", "profile", 2));
        Actions a = BehaviorService.assembleActions(
                List.of(new KindRow("follow", 2, 1), new KindRow("like", 28, 9)), screens);
        assertThat(a.items()).extracting(x -> x.kind()).containsExactly("like", "follow");
        assertThat(a.items().get(0).perScreen()).hasSize(5);
        assertThat(a.items().get(0).perScreen().get(0).screen()).isEqualTo("s7");
        assertThat(a.items().get(0).users()).isEqualTo(9);
    }

    @Test
    void likeEscapesWildcards() {
        assertThat(BehaviorService.escapeLike("a%b_c\\d")).isEqualTo("a\\%b\\_c\\\\d");
    }

    @Test
    void actionKindQueryListMatchesContractWhitelist() {
        assertThat(BehaviorService.ACTION_KINDS).containsExactlyInAnyOrderElementsOf(EventContract.ACTION_KINDS);
    }

    @Test
    void sqlSessionDefinitionsComeFromMathConstants() {
        var p = BehaviorSql.params(DateRange.dayStart(LocalDate.parse("2026-11-01")), DateRange.dayStart(LocalDate.parse("2026-11-02")));
        assertThat(p.getValue("gapSecs")).isEqualTo(1800L);
        assertThat(p.getValue("bounceMs")).isEqualTo(10_000L);
        assertThat(p.getValue("quickMs")).isEqualTo(5_000L);
        assertThat(p.getValue("bounceScreens")).isEqualTo(1);
    }
}
