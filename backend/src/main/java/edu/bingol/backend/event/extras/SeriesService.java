package edu.bingol.backend.event.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.extras.ExtrasDtos.SeriesItem;
import edu.bingol.backend.event.extras.ExtrasDtos.SeriesView;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Haftalik tekrar: mevcut etkinlikten 1-11 ek kopya (toplam en fazla 12). Kopyalar bagimsiz etkinliktir (kendi
 * RSVP/yoklama/kapasite); kapak, ortak organizator ve alim ayari kopyalanmaz. Seri iptali bu ve sonraki tekrarlari kapatir.
 */
@Service
public class SeriesService {

    static final int MAX_EXTRA = 11;
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final Instant LIMIT = Instant.parse("2099-12-31T00:00:00Z");

    private final EventService events;
    private final UserEventRepository eventRepo;
    private final EventSeriesMemberRepository members;

    public SeriesService(EventService events, UserEventRepository eventRepo, EventSeriesMemberRepository members) {
        this.events = events;
        this.eventRepo = eventRepo;
        this.members = members;
    }

    @Transactional
    public SeriesView create(Actor a, Long eventId, int count, Instant now) {
        if (count < 1 || count > MAX_EXTRA) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_SERIES_COUNT",
                    "Tekrar sayısı 1 ile " + MAX_EXTRA + " arasında olmalı.", String.valueOf(MAX_EXTRA));
        }
        UserEvent src = events.requireManager(a, events.load(eventId));
        if (src.getStatus() != UserEvent.Status.ACTIVE && src.getStatus() != UserEvent.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_EDITABLE", "Bu etkinlik düzenlenemez.");
        }
        if (!src.getEndsAt().isAfter(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Etkinlik sona erdi.");
        }
        if (members.findByEventId(eventId).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_IN_SERIES", "Bu etkinlik zaten bir serinin parçası.");
        }
        if (src.getEndsAt().atZone(ZONE).plusWeeks(count).toInstant().isAfter(LIMIT)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Tarih aralığı geçersiz.");
        }
        List<EventSeriesMember> out = new ArrayList<>();
        out.add(new EventSeriesMember(eventId, eventId, 0));
        for (int i = 1; i <= count; i++) {
            UserEvent c = new UserEvent();
            c.setTitle(src.getTitle());
            c.setDescription(src.getDescription());
            c.setLocation(src.getLocation());
            c.setCapacity(src.getCapacity());
            c.setCommunityId(src.getCommunityId());
            c.setCreatedBy(src.getCreatedBy());
            c.setStatus(src.getStatus());
            // Duvar saati korunur (ZonedDateTime); yaz saati olsa da ayni yerel saat.
            c.setStartsAt(src.getStartsAt().atZone(ZONE).plusWeeks(i).toInstant());
            c.setEndsAt(src.getEndsAt().atZone(ZONE).plusWeeks(i).toInstant());
            eventRepo.save(c);
            out.add(new EventSeriesMember(c.getId(), eventId, i));
        }
        members.saveAll(out);
        return view(eventId, out, eventRepo.findAllById(out.stream().map(EventSeriesMember::getEventId).toList()));
    }

    @Transactional(readOnly = true)
    public SeriesView get(Actor a, Long eventId) {
        events.loadVisible(a, eventId);
        EventSeriesMember m = members.findByEventId(eventId).orElseThrow(SeriesService::notFound);
        List<EventSeriesMember> all = members.findBySeriesIdOrderBySeq(m.getSeriesId());
        List<UserEvent> evs = eventRepo.findAllById(all.stream().map(EventSeriesMember::getEventId).toList());
        // Gorunmeyen (onay bekleyen vb.) uyeler yalnizca organizatorlere gosterilir.
        List<UserEvent> shown = evs.stream()
                .filter(e -> e.getStatus() == UserEvent.Status.ACTIVE || e.getStatus() == UserEvent.Status.CANCELLED
                        || events.canManage(a, e))
                .toList();
        return view(m.getSeriesId(), all, shown);
    }

    /** Bu etkinlik ve sonraki tum tekrarlar iptal edilir (gecmis/iptal olanlara dokunulmaz). Doner: iptal edilen sayi. */
    @Transactional
    public int cancelFromHere(Actor a, Long eventId, Instant now) {
        events.requireManager(a, events.load(eventId));
        EventSeriesMember m = members.findByEventId(eventId).orElseThrow(SeriesService::notFound);
        List<EventSeriesMember> all = members.findBySeriesIdOrderBySeq(m.getSeriesId());
        Map<Long, UserEvent> byId = eventRepo.findAllById(all.stream().map(EventSeriesMember::getEventId).toList())
                .stream().collect(Collectors.toMap(UserEvent::getId, Function.identity()));
        int n = 0;
        for (EventSeriesMember x : all) {
            UserEvent e = byId.get(x.getEventId());
            if (x.getSeq() < m.getSeq() || e == null || e.getStatus() == UserEvent.Status.CANCELLED
                    || !e.getEndsAt().isAfter(now) || !events.canManage(a, e)) {
                continue;
            }
            events.delete(a, e.getId());
            n++;
        }
        return n;
    }

    private static SeriesView view(Long seriesId, List<EventSeriesMember> ms, List<UserEvent> evs) {
        Map<Long, UserEvent> byId = evs.stream().collect(Collectors.toMap(UserEvent::getId, Function.identity()));
        List<SeriesItem> items = new ArrayList<>();
        for (EventSeriesMember x : ms) {
            UserEvent e = byId.get(x.getEventId());
            if (e != null) {
                items.add(new SeriesItem(e.getId(), x.getSeq(), e.getStartsAt(), e.getEndsAt(), e.getStatus().name()));
            }
        }
        return new SeriesView(seriesId, items);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "SERIES_NOT_FOUND", "Bu etkinlik bir seriye ait değil.");
    }
}
