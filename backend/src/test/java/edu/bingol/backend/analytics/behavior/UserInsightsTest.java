package edu.bingol.backend.analytics.behavior;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

import edu.bingol.backend.analytics.DateRange;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserInfo;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Ev;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class UserInsightsTest {
    private static final Instant AT = Instant.parse("2026-11-01T21:30:00Z"); // Nov 2, 00:30 Istanbul

    private Ev event(long id, String name, String screen, Long dwell, String kind) {
        return new Ev(id, name, screen, "session", kind, dwell, null, null, null, AT.plusMillis(id));
    }

    @Test
    void fullPageTotalsAreIndependentOfTimelineStepLimitAndKeepUnknownDurationUnknown() {
        List<Ev> events = new ArrayList<>();
        for (int i = 0; i < 120; i++) {
            events.add(event(i * 2, "screen_view", "/chat", null, null));
            events.add(event(i * 2 + 1, "screen_exit", "/chat", 1000L, null));
        }
        events.add(event(300, "screen_view", "/menu", null, null));
        events.add(event(301, "action", "/chat", null, "send_message"));
        events.add(event(302, "action", "/chat", null, null));
        var sessions = BehaviorMath.sessionize(events);
        assertThat(sessions.get(0).steps()).hasSize(100);
        var result = UserInsightsBuilder.build(new DateRange(LocalDate.parse("2026-11-01"), LocalDate.parse("2026-11-03")), events, sessions);
        var chat = result.screens().get(0);
        assertThat(chat.screen()).isEqualTo("/chat");
        assertThat(chat.views()).isEqualTo(120);
        assertThat(chat.totalMs()).isEqualTo(120_000);
        assertThat(chat.avgMs()).isEqualTo(1000);
        assertThat(chat.maxMs()).isEqualTo(1000);
        assertThat(chat.share()).isEqualTo(1);
        assertThat(result.screens().get(1).measuredVisits()).isZero();
        assertThat(result.byDay()).hasSize(3);
        assertThat(result.byDay().get(0).sessions()).isZero();
        assertThat(result.byDay().get(1).views()).isEqualTo(121);
        assertThat(result.byHour()).hasSize(24);
        assertThat(result.byHour().get(0).views()).isEqualTo(121);
        assertThat(result.actions()).hasSize(1);
        assertThat(result.actions().get(0).kind()).isEqualTo("send_message");
        assertThat(result.partial()).isFalse();
    }

    @Test
    void selectedHistoricalDatesReachRepositoryInsteadOfBeingReplacedWithRecentDays() {
        var repo = mock(BehaviorRepository.class);
        var service = new BehaviorService(repo, Clock.fixed(Instant.parse("2026-11-09T10:00:00Z"), ZoneOffset.UTC));
        var range = new DateRange(LocalDate.parse("2026-10-01"), LocalDate.parse("2026-10-03"));
        when(repo.userInfo(7)).thenReturn(Optional.of(new UserInfo(7, "Test", "test@example.com", null, null)));
        when(repo.userEvents(7, range.startUtc(), range.endUtc())).thenReturn(List.of());
        var detail = service.userDetail(7, null, "2026-10-01", "2026-10-03");
        verify(repo).userEvents(7, range.startUtc(), range.endUtc());
        assertThat(detail.insights().from()).isEqualTo("2026-10-01");
        assertThat(detail.insights().byDay()).hasSize(3);
        assertThat(detail.insights().screens()).isEmpty();
        assertThat(detail.summary().sessions()).isZero();
    }

    @Test
    void capIsVisibleInsteadOfPresentingSampleAsCompleteHistory() {
        var range = new DateRange(LocalDate.parse("2026-11-02"), LocalDate.parse("2026-11-02"));
        var events = java.util.Collections.nCopies(BehaviorRepository.USER_EVENT_CAP,
                event(1, "screen_view", "/home", null, null));
        assertThat(UserInsightsBuilder.build(range, events, List.of()).partial()).isTrue();
    }
}
