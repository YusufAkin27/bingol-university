package edu.bingol.backend.notification;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsUpdate;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsView;
import edu.bingol.backend.notification.dto.NotificationDtos.QuietHoursView;
import java.util.HashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Bildirim tercihleri: ana bayraklar, sessiz saatler, alt tur bayraklari. */
@Service
public class NotificationPrefService {

    private final NotificationPrefRepository prefs;
    private final NotificationSubtypePrefRepository subtypePrefs;

    public NotificationPrefService(NotificationPrefRepository prefs, NotificationSubtypePrefRepository subtypePrefs) {
        this.prefs = prefs;
        this.subtypePrefs = subtypePrefs;
    }

    public PrefsView get(Long userId) {
        return view(prefs.findById(userId).orElseGet(() -> NotificationPref.defaults(userId)), userId);
    }

    @Transactional
    public PrefsView update(Long userId, PrefsUpdate r) {
        NotificationPref p = prefs.findById(userId).orElseGet(() -> NotificationPref.defaults(userId));
        // Once dogrula, sonra yaz: kismi basarisiz guncelleme olmasin.
        int qs = p.getQuietStart();
        int qe = p.getQuietEnd();
        String tz = p.getTimezone();
        boolean qen = p.isQuietEnabled();
        QuietHoursView q = r.quietHours();
        if (q != null) {
            qen = q.enabled();
            if (q.start() != null) {
                qs = QuietHoursView.parse(q.start());
            }
            if (q.end() != null) {
                qe = QuietHoursView.parse(q.end());
            }
            if (q.timezone() != null) {
                tz = q.timezone();
            }
            if (!QuietHours.validZone(tz) || qs == qe) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUIET_HOURS", "Sessiz saat ayarı geçersiz.");
            }
        }
        Map<NotificationSubtype, Boolean> subs = new HashMap<>();
        if (r.subtypes() != null) {
            for (Map.Entry<String, Boolean> e : r.subtypes().entrySet()) {
                NotificationSubtype s = NotificationSubtype.parse(e.getKey());
                if (s == null || e.getValue() == null) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_SUBTYPE", "Bilinmeyen bildirim alt türü.");
                }
                subs.put(s, e.getValue());
            }
        }

        if (r.news() != null) p.setNews(r.news());
        if (r.announcements() != null) p.setAnnouncements(r.announcements());
        if (r.events() != null) p.setEvents(r.events());
        if (r.messages() != null) p.setMessages(r.messages());
        if (r.communities() != null) p.setCommunities(r.communities());
        p.setQuietEnabled(qen);
        p.setQuietStart(qs);
        p.setQuietEnd(qe);
        p.setTimezone(tz);
        prefs.save(p);

        for (Map.Entry<NotificationSubtype, Boolean> e : subs.entrySet()) {
            NotificationSubtypePref row = subtypePrefs.findByUserIdAndSubtype(userId, e.getKey().name())
                    .orElseGet(() -> {
                        NotificationSubtypePref n = new NotificationSubtypePref();
                        n.setUserId(userId);
                        n.setSubtype(e.getKey().name());
                        return n;
                    });
            row.setEnabled(e.getValue());
            subtypePrefs.save(row);
        }
        return view(p, userId);
    }

    private PrefsView view(NotificationPref p, Long userId) {
        Map<String, Boolean> overrides = new HashMap<>();
        subtypePrefs.findByUserId(userId).forEach(s -> overrides.put(s.getSubtype(), s.isEnabled()));
        return PrefsView.of(p, overrides);
    }
}
