package edu.bingol.backend.analytics.behavior;

import edu.bingol.backend.analytics.DateRange;
import edu.bingol.backend.analytics.EventContract;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.*;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Ev;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Session;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Aggregate raw events before the timeline's 50-session / 100-step presentation limits. */
final class UserInsightsBuilder {
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private UserInsightsBuilder() {}

    static UserInsights build(DateRange range, List<Ev> events, List<Session> sessions) {
        Map<String, long[]> screens = new LinkedHashMap<>();
        Map<LocalDate, long[]> days = new LinkedHashMap<>();
        Map<String, Integer> actions = new LinkedHashMap<>();
        long[][] hours = new long[24][2];
        for (LocalDate d = range.from(); !d.isAfter(range.to()); d = d.plusDays(1)) {
            days.put(d, new long[4]);
        }
        for (Session session : sessions) {
            long[] day = days.get(session.startedAt().atZone(ZONE).toLocalDate());
            if (day != null) {
                day[0]++;
                day[1] += session.durationMs();
            }
        }
        for (Ev event : events) {
            var at = event.at().atZone(ZONE);
            long[] day = days.get(at.toLocalDate());
            if (day == null) continue;
            if (event.name().equals("screen_view")) {
                day[2]++;
                hours[at.getHour()][0]++;
                if (event.screen() != null && !event.screen().isBlank()) {
                    screens.computeIfAbsent(event.screen(), k -> new long[5])[0]++;
                }
            } else if (event.name().equals("screen_exit") && event.dwellMs() != null
                    && event.screen() != null && !event.screen().isBlank()) {
                long[] screen = screens.computeIfAbsent(event.screen(), k -> new long[5]);
                long ms = Math.max(0, event.dwellMs());
                screen[1]++;
                screen[2] += ms;
                screen[3] = Math.max(screen[3], ms);
            } else if (event.name().equals("action") && event.kind() != null
                    && EventContract.ACTION_KINDS.contains(event.kind())) {
                day[3]++;
                hours[at.getHour()][1]++;
                actions.merge(event.kind(), 1, Integer::sum);
            }
        }
        long total = screens.values().stream().mapToLong(s -> s[2]).sum();
        List<UserScreen> screenRows = screens.entrySet().stream().map(e -> {
            long[] s = e.getValue();
            return new UserScreen(e.getKey(), (int) s[0], (int) s[1], s[2],
                    s[1] == 0 ? 0 : Math.round((double) s[2] / s[1]), s[3], BehaviorMath.ratio(s[2], total));
        }).sorted(Comparator.comparingLong(UserScreen::totalMs).reversed()
                .thenComparing(Comparator.comparingInt(UserScreen::views).reversed())
                .thenComparing(UserScreen::screen)).toList();
        List<UserDay> dayRows = days.entrySet().stream().map(e -> new UserDay(e.getKey().toString(),
                (int) e.getValue()[0], e.getValue()[1], (int) e.getValue()[2], (int) e.getValue()[3])).toList();
        List<UserHour> hourRows = new ArrayList<>();
        for (int h = 0; h < 24; h++) hourRows.add(new UserHour(h, (int) hours[h][0], (int) hours[h][1]));
        List<UserAction> actionRows = actions.entrySet().stream().map(e -> new UserAction(e.getKey(), e.getValue()))
                .sorted(Comparator.comparingInt(UserAction::count).reversed().thenComparing(UserAction::kind)).toList();
        return new UserInsights(range.from().toString(), range.to().toString(), screenRows, dayRows, hourRows,
                actionRows, events.size(), events.size() >= BehaviorRepository.USER_EVENT_CAP);
    }
}
