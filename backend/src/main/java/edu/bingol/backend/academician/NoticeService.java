package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcNotice.Type;
import edu.bingol.backend.academician.AcademicianDtos.FileView;
import edu.bingol.backend.academician.AcademicianDtos.NoticeRequest;
import edu.bingol.backend.academician.AcademicianDtos.NoticeView;
import edu.bingol.backend.academician.NoticeRules.Clean;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Ders duyurulari: akademisyen kayitli ogrencilere YALNIZ sabit turlerde bildirim gonderir (serbest metin yayini yok).
 * Tur basina alan kurallari {@link NoticeRules}'ta. Sabit turler: LESSON_STARTED, ATTENDANCE_STARTED, EXAM, ASSIGNMENT,
 * MATERIAL, LESSON_CANCELLED, ROOM_CHANGED. EXAM/ASSIGNMENT/MATERIAL en cok 5 dosya tasiyabilir (NoticeFileService).
 * Teslimat mevcut bildirim hattindandir (AcademicianNotifier) ve duyuru + tum dosyalar yazildiktan SONRA gider.
 * Sinirlar: ders basina gunde 20 duyuru; LESSON_STARTED/ATTENDANCE_STARTED ders basina 10 dakikada en cok bir kez
 * (429 NOTICE_TOO_FREQUENT).
 */
@Service
public class NoticeService {

    static final int DAILY_LIMIT = 20;
    static final Duration REPEAT_WINDOW = Duration.ofMinutes(10);

    private final AcademicianGuard guard;
    private final AcNoticeRepository notices;
    private final NoticeFileService files;
    private final AcademicianNotifier notifier;
    private final Clock clock;
    private final AcCourseRepository courseRepo;
    private final TransactionTemplate tx;

    public NoticeService(AcademicianGuard guard, AcNoticeRepository notices, NoticeFileService files,
                         AcademicianNotifier notifier, Clock clock, PlatformTransactionManager tm, AcCourseRepository courseRepo) {
        this.courseRepo = courseRepo;
        this.guard = guard;
        this.notices = notices;
        this.files = files;
        this.notifier = notifier;
        this.clock = clock;
        this.tx = new TransactionTemplate(tm);
    }

    public NoticeView send(Long userId, Long courseId, NoticeRequest r) {
        AcCourse course = guard.ownCourse(userId, courseId);
        return create(course, userId, r);
    }

    /** Oturum acilisinda notify=true: ATTENDANCE_STARTED (ayni sinirlar; ihlalde ApiException firlatir, cagiran yutar). */
    NoticeView autoAttendanceStarted(AcCourse course, Long userId) {
        return create(course, userId, new NoticeRequest(Type.ATTENDANCE_STARTED, null, null, null, null));
    }

    private NoticeView create(AcCourse course, Long userId, NoticeRequest r) {
        Type type = r.type();
        List<AcNoticeFile> pending = files.requirePending(course.getId(), userId, r.fileIds());
        Clean c = NoticeRules.validate(type, r.title(), r.note(), r.eventAt(), pending.size());
        Instant now = clock.instant();
        Long courseId = course.getId();
        Instant dayStart = LocalDate.now(clock.withZone(AcSessionService.ZONE)).atStartOfDay(AcSessionService.ZONE).toInstant();
        AcNotice n = new AcNotice();
        n.setCourseId(courseId);
        n.setType(type);
        n.setTitle(c.title());
        n.setNote(c.note());
        n.setEventAt(c.eventAt());
        n.setCreatedBy(userId);
        n.setCreatedAt(now);
        // kilit + sinir + duyuru + dosya baglari TEK islemde: es zamanli iki istek sinirlari birlikte asamaz, ayni dosya iki duyuruya baglanamaz;
        // bildirim ancak hepsi yazildiktan sonra gider. Silinmis (yumusak) duyurular da sinirlara SAYILIR.
        AcNotice saved = tx.execute(s -> {
            courseRepo.lockById(courseId);
            if (notices.countSince(courseId, dayStart) >= DAILY_LIMIT) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "NOTICE_DAILY_LIMIT",
                        "Bir derse günde en fazla " + DAILY_LIMIT + " duyuru gönderilebilir.", String.valueOf(DAILY_LIMIT));
            }
            if ((type == Type.LESSON_STARTED || type == Type.ATTENDANCE_STARTED)
                    && notices.countTypesSince(courseId, List.of(type), now.minus(REPEAT_WINDOW)) > 0) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "NOTICE_TOO_FREQUENT",
                        "Bu bildirim 10 dakikada en fazla bir kez gönderilebilir.");
            }
            AcNotice x = notices.save(n);
            files.attach(pending, x.getId());
            return x;
        });
        notifier.courseNotice(course, type, c.title(), c.eventAt(), c.note());
        return view(saved, pending.stream().map(NoticeFileService::view).toList());
    }

    public CursorPage<NoticeView> list(Long userId, Long courseId, Long cursor, int size) {
        guard.ownCourse(userId, courseId);
        return page(courseId, cursor, size);
    }

    CursorPage<NoticeView> page(Long courseId, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<AcNotice> rows = notices.page(courseId, cursor == null ? Long.MAX_VALUE : cursor, PageRequest.of(0, s + 1));
        Map<Long, List<FileView>> fv = files.viewsByNotice(rows.stream().limit(s).map(AcNotice::getId).toList());
        return CursorPage.of(rows, s, AcNotice::getId, n -> view(n, fv.getOrDefault(n.getId(), List.of())));
    }

    /**
     * Yumusak silme: duyuru listelerden (ogrenci dahil) kalkar, dosya satirlari ve depo nesneleri silinir; satir kalir ki
     * sinir sayaclari onu saymaya devam etsin. Baska hocanin/olmayan duyuru ayni 404 AC_NOTICE_NOT_FOUND.
     */
    public void delete(Long userId, Long noticeId) {
        AcNotice n = notices.findById(noticeId).filter(x -> x.getDeletedAt() == null).orElseThrow(AcErrors::noticeNotFound);
        ownCourseOrNoticeNotFound(guard, userId, n.getCourseId());
        List<String> keys = tx.execute(s -> {
            List<String> k = files.removeRowsOfNotice(noticeId);
            AcNotice x = notices.findById(noticeId).orElseThrow(AcErrors::noticeNotFound);
            x.setDeletedAt(clock.instant());
            notices.save(x);
            return k;
        });
        files.deleteObjects(keys == null ? List.of() : keys);
    }

    /** Duyuru kimligi kimin oldugunu sizdirmasin: sahiplik hatasi da AC_NOTICE_NOT_FOUND. */
    static AcCourse ownCourseOrNoticeNotFound(AcademicianGuard guard, Long userId, Long courseId) {
        try {
            return guard.ownCourse(userId, courseId);
        } catch (ApiException e) {
            if ("AC_COURSE_NOT_FOUND".equals(e.code())) {
                throw AcErrors.noticeNotFound();
            }
            throw e;
        }
    }

    static NoticeView view(AcNotice n, List<FileView> fileViews) {
        return new NoticeView(n.getId(), n.getType().name(), n.getTitle(), n.getNote(), n.getEventAt(), n.getCreatedAt(),
                fileViews);
    }
}
