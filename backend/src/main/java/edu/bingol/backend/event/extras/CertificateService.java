package edu.bingol.backend.event.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventAttendance;
import edu.bingol.backend.event.EventAttendanceRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.extras.ExtrasDtos.Certificate;
import edu.bingol.backend.event.extras.ExtrasDtos.CertificateVerification;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.security.SecureRandom;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Katilim sertifikasi VERISI (PDF uretimi yok). Kod: 20 karakter Base32 (100 bit, SecureRandom) - tahmin edilemez.
 * Dogrulama herkese aciktir ama gecersiz/iptal olmus sertifika kisi bilgisi sizdirmaz.
 */
@Service
public class CertificateService {

    static final int CODE_LENGTH = 20;
    private static final String ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private static final Pattern CODE_FORMAT = Pattern.compile("^[A-Z2-7]{" + CODE_LENGTH + "}$");
    private static final SecureRandom RANDOM = new SecureRandom();

    private final EventService events;
    private final UserEventRepository eventRepo;
    private final EventAttendanceRepository attendance;
    private final EventCertificateRepository repo;
    private final CommunityService communities;

    public CertificateService(EventService events, UserEventRepository eventRepo, EventAttendanceRepository attendance,
                              EventCertificateRepository repo, CommunityService communities) {
        this.events = events;
        this.eventRepo = eventRepo;
        this.attendance = attendance;
        this.repo = repo;
        this.communities = communities;
    }

    /** Idempotent: ilk cagri duzenler, sonrakiler ayni sertifikayi dondurur. */
    @Transactional
    public Certificate issue(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        if (!attended(eventId, a.id())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EVENT_NOT_ATTENDED",
                    "Bu işlem için etkinliğe katılmış (yoklaması alınmış) olmalısınız.");
        }
        EventCertificate c = repo.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        if (c == null) {
            User u = communities.usersById(List.of(a.id())).get(a.id());
            c = new EventCertificate();
            c.setEventId(eventId);
            c.setUserId(a.id());
            c.setCode(newCode());
            c.setHolderName(u == null ? "Kullanıcı" : u.getDisplayName());
            try {
                repo.saveAndFlush(c);
            } catch (DataIntegrityViolationException ex) {
                // Es zamanli ikinci istek: islem geri alinir, istemci tekrar denediginde mevcut sertifikayi alir.
                throw new ApiException(HttpStatus.CONFLICT, "CERTIFICATE_CONFLICT", "İşleniyor, tekrar deneyin.");
            }
        }
        return new Certificate(c.getCode(), "/api/certificates/verify/" + c.getCode(), c.getHolderName(), eventId,
                e.getTitle(), e.getStartsAt(), e.getEndsAt(), e.getLocation(), c.getIssuedAt());
    }

    @Transactional(readOnly = true)
    public CertificateVerification verify(String rawCode) {
        String code = rawCode == null ? "" : rawCode.trim().toUpperCase(Locale.ROOT).replace("-", "").replace(" ", "");
        if (!CODE_FORMAT.matcher(code).matches()) {
            throw notFound();
        }
        EventCertificate c = repo.findByCode(code).orElseThrow(CertificateService::notFound);
        UserEvent e = eventRepo.findById(c.getEventId()).orElse(null);
        User u = communities.usersById(List.of(c.getUserId())).get(c.getUserId());
        boolean valid = e != null && e.getStatus() != UserEvent.Status.CANCELLED && e.getStatus() != UserEvent.Status.HIDDEN
                && u != null && u.getStatus() != UserStatus.DELETED
                && attended(c.getEventId(), c.getUserId());
        if (!valid) {
            return new CertificateVerification(false, null, null, null, null, null);
        }
        return new CertificateVerification(true, c.getHolderName(), e.getTitle(), e.getStartsAt(), e.getEndsAt(),
                c.getIssuedAt());
    }

    static String newCode() {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }

    private boolean attended(Long eventId, Long userId) {
        return attendance.findByEventIdAndUserId(eventId, userId).filter(EventAttendance::isPresent).isPresent();
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CERTIFICATE_NOT_FOUND", "Sertifika bulunamadı.");
    }
}
