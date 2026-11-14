package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.MyCourseView;
import edu.bingol.backend.academician.AcademicianDtos.NoticeView;
import edu.bingol.backend.academician.AcademicianDtos.UpcomingView;
import edu.bingol.backend.common.CursorPage;
import java.time.Clock;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Ogrencinin "Derslerim" gorunumu: kayitli oldugu dersler + devamsizlik sayilari/sinir durumu, ders duyurulari ve yaklasan
 * sinav/odevler. Yalniz ogrencinin kendi kayitlari; baska ogrenci ya da baska dersin verisi donmez.
 */
@Service
public class StudentCourseService {

    static final int MAX_COURSES = 100;
    static final int UPCOMING_MAX = 50;

    private final AcEnrollmentRepository enrollments;
    private final AcCourseRepository courses;
    private final AttendanceStats stats;
    private final AcademicianRepository academicians;
    private final AcNoticeRepository notices;
    private final NoticeService noticeService;
    private final NoticeFileService noticeFiles;
    private final Clock clock;

    public StudentCourseService(AcEnrollmentRepository enrollments, AcCourseRepository courses, AttendanceStats stats,
                                AcademicianRepository academicians,
                                AcNoticeRepository notices, NoticeService noticeService, NoticeFileService noticeFiles,
                                Clock clock) {
        this.enrollments = enrollments;
        this.courses = courses;
        this.stats = stats;
        this.academicians = academicians;
        this.notices = notices;
        this.noticeService = noticeService;
        this.noticeFiles = noticeFiles;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<MyCourseView> myCourses(Long studentId) {
        List<Long> ids = enrollments.courseIdsOf(studentId, PageRequest.of(0, MAX_COURSES));
        if (ids.isEmpty()) {
            return List.of();
        }
        List<AcCourse> cs = courses.byIds(ids);
        // sayim kurali matrisle AYNI fonksiyondan (AttendanceMath): canli/sayilmayan/kayit oncesi/izinli oturumlar sayilmaz
        Map<Long, AttendanceMath.Result> res = stats.forStudent(studentId, cs, clock.instant());
        Map<Long, String> owners = academicians.findAllById(cs.stream().map(AcCourse::getOwnerId).distinct().toList()).stream()
                .collect(Collectors.toMap(Academician::getUserId, Academician::fullName));
        return cs.stream().sorted(Comparator.comparing(AcCourse::getName, String.CASE_INSENSITIVE_ORDER)).map(c -> {
            AttendanceMath.Result r = res.get(c.getId());
            AcademicianDtos.LimitView lim = CourseService.limitOf(c);
            return new MyCourseView(c.getId(), c.getName(), c.getCode(), c.getTerm(), owners.get(c.getOwnerId()), r.present(),
                    r.absent(), r.excused(), r.sessionCount(), lim.type() == null ? null : lim, r.atRisk(), r.overLimit());
        }).toList();
    }

    @Transactional(readOnly = true)
    public CursorPage<NoticeView> notices(Long studentId, Long courseId, Long cursor, int size) {
        if (!enrollments.existsByCourseIdAndStudentId(courseId, studentId)) {
            throw AcErrors.notEnrolled();
        }
        return noticeService.page(courseId, cursor, size);
    }

    @Transactional(readOnly = true)
    public List<UpcomingView> upcoming(Long studentId) {
        List<Long> ids = enrollments.courseIdsOf(studentId, PageRequest.of(0, MAX_COURSES));
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, String> names = courses.byIds(ids).stream().collect(Collectors.toMap(AcCourse::getId, AcCourse::getName));
        List<AcNotice> rows = notices.upcoming(ids, java.util.Arrays.stream(AcNotice.Type.values())
                .filter(NoticeRules::upcomingEligible).toList(), clock.instant(), PageRequest.of(0, UPCOMING_MAX));
        Map<Long, List<AcademicianDtos.FileView>> fv = noticeFiles.viewsByNotice(rows.stream().map(AcNotice::getId).toList());
        return rows.stream()
                .map(n -> new UpcomingView(n.getId(), n.getCourseId(), names.get(n.getCourseId()), n.getType().name(),
                        n.getTitle(), n.getNote(), n.getEventAt(), fv.getOrDefault(n.getId(), List.of()))).toList();
    }
}
