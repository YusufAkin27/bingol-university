package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.CoursePatch;
import edu.bingol.backend.academician.AcademicianDtos.CourseRequest;
import edu.bingol.backend.academician.AcademicianDtos.CourseView;
import edu.bingol.backend.academician.AcademicianDtos.LimitView;
import edu.bingol.backend.academician.AcademicianDtos.SlotRequest;
import edu.bingol.backend.academician.AcademicianDtos.SlotView;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Akademisyenin dersleri ve haftalik programi. Her cagri onayli akademisyen + dersin sahibi ister (baskasininki 404). */
@Service
public class CourseService {

    static final int MAX_COURSES_LISTED = 200;
    static final int MAX_SLOTS = 30;
    private static final Pattern HHMM = Pattern.compile("^([01][0-9]|2[0-3]):[0-5][0-9]$");

    private final AcademicianGuard guard;
    private final AcCourseRepository courses;
    private final AcCourseSlotRepository slots;
    private final AcEnrollmentRepository enrollments;
    private final AcSessionRepository sessions;
    private final CatalogService catalog;
    private final AcademicianAccountPurger purger;
    private final AbsenceWarningService warnings;
    private final AcademicianRepository academicians;
    private final AcademicianProperties props;

    public CourseService(AcademicianGuard guard, AcCourseRepository courses, AcCourseSlotRepository slots,
                         AcEnrollmentRepository enrollments, AcSessionRepository sessions, CatalogService catalog,
                         AcademicianAccountPurger purger, AbsenceWarningService warnings,
                         AcademicianRepository academicians, AcademicianProperties props) {
        this.guard = guard;
        this.courses = courses;
        this.slots = slots;
        this.enrollments = enrollments;
        this.sessions = sessions;
        this.catalog = catalog;
        this.purger = purger;
        this.warnings = warnings;
        this.academicians = academicians;
        this.props = props;
    }

    @Transactional(readOnly = true)
    public List<CourseView> list(Long userId) {
        guard.requireApproved(userId);
        List<AcCourse> rows = courses.ofOwner(userId, PageRequest.of(0, MAX_COURSES_LISTED));
        return views(rows);
    }

    /** Yonetici okumasi: sahiplik aranmaz. */
    @Transactional(readOnly = true)
    public List<CourseView> listForAdmin(Long ownerId) {
        return views(courses.ofOwner(ownerId, PageRequest.of(0, MAX_COURSES_LISTED)));
    }

    @Transactional(readOnly = true)
    public CourseView getForAdmin(Long courseId) {
        return detail(courses.findById(courseId).orElseThrow(AcErrors::courseNotFound));
    }

    @Transactional
    public CourseView create(Long userId, CourseRequest r) {
        guard.requireApproved(userId);
        academicians.lockById(userId); // es zamanli olusturmalar siniri birlikte asamaz
        if (courses.countByOwnerId(userId) >= props.maxCourses()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "AC_COURSE_LIMIT",
                    "En fazla " + props.maxCourses() + " ders oluşturulabilir.", String.valueOf(props.maxCourses()));
        }
        AcCourse c = new AcCourse();
        if (r.plannedSessions() != null) {
            c.setPlannedSessions(r.plannedSessions().shortValue());
        }
        c.setOwnerId(userId);
        c.setCode(AcademicianService.clean(r.code(), "code", 30, false));
        c.setName(AcademicianService.clean(r.name(), "name", 200, true));
        c.setTerm(AcademicianService.clean(r.term(), "term", 40, true));
        c.setFaculty(AcademicianService.clean(r.faculty(), "faculty", 160, false));
        c.setDepartment(AcademicianService.clean(r.department(), "department", 160, true));
        c.setGrade(AcademicianService.clean(r.grade(), "grade", 8, false));
        validateAudience(c.getFaculty(), c.getDepartment(), c.getGrade());
        return detail(courses.save(c));
    }

    @Transactional(readOnly = true)
    public CourseView get(Long userId, Long courseId) {
        return detail(guard.ownCourse(userId, courseId));
    }

    public CourseView patch(Long userId, Long courseId, CoursePatch p) {
        AcCourse c = guard.ownCourse(userId, courseId);
        if (p.code() != null) {
            c.setCode(AcademicianService.clean(p.code(), "code", 30, false));
        }
        if (p.name() != null) {
            c.setName(AcademicianService.clean(p.name(), "name", 200, true));
        }
        if (p.term() != null) {
            c.setTerm(AcademicianService.clean(p.term(), "term", 40, true));
        }
        boolean audience = p.faculty() != null || p.department() != null || p.grade() != null;
        if (p.faculty() != null) {
            c.setFaculty(AcademicianService.clean(p.faculty(), "faculty", 160, false));
        }
        if (p.department() != null) {
            c.setDepartment(AcademicianService.clean(p.department(), "department", 160, true));
        }
        if (p.grade() != null) {
            c.setGrade(AcademicianService.clean(p.grade(), "grade", 8, false));
        }
        if (audience) {
            validateAudience(c.getFaculty(), c.getDepartment(), c.getGrade());
        }
        boolean limitChanged = p.absenceLimitType() != null || p.absenceLimitValue() != null || p.plannedSessions() != null;
        if (p.plannedSessions() != null) {
            c.setPlannedSessions(p.plannedSessions() == 0 ? null : p.plannedSessions().shortValue());
        }
        applyLimit(c, p.absenceLimitType(), p.absenceLimitValue());
        if (p.status() != null) {
            try {
                c.setStatus(AcCourse.Status.valueOf(p.status().trim().toUpperCase(Locale.ROOT)));
            } catch (IllegalArgumentException e) {
                throw AcErrors.invalid("status");
            }
        }
        c.setUpdatedAt(Instant.now());
        AcCourse saved = courses.save(c);
        if (limitChanged) {
            warnings.recomputeLowering(saved.getId(), null); // sinir/planlanan degisti: duzeyler yeniden hesaplanir (dusebilir)
        }
        return detail(saved);
    }

    @Transactional
    public void delete(Long userId, Long courseId) {
        AcCourse c = guard.ownCourse(userId, courseId);
        purger.deleteCourse(c.getId());
    }

    /** Haftalik programi degistirir (liste tamamen yenilenir). Silinen saate bagli oturumlarin slot_id'si bosalir. */
    @Transactional
    public List<SlotView> replaceSlots(Long userId, Long courseId, List<SlotRequest> req) {
        AcCourse c = guard.ownCourse(userId, courseId);
        if (req == null || req.size() > MAX_SLOTS) {
            throw AcErrors.invalid("slots");
        }
        List<AcCourseSlot> next = new ArrayList<>();
        for (SlotRequest r : req) {
            AcCourseSlot s = new AcCourseSlot();
            s.setCourseId(c.getId());
            s.setDayOfWeek((short) r.dayOfWeek());
            s.setStartTime(time(r.startTime(), "startTime"));
            s.setEndTime(time(r.endTime(), "endTime"));
            if (!s.getEndTime().isAfter(s.getStartTime())) {
                throw AcErrors.invalid("endTime");
            }
            s.setRoom(AcademicianService.clean(r.room(), "room", 100, false));
            next.add(s);
        }
        sessions.clearSlots(c.getId());
        slots.deleteByCourse(c.getId());
        slots.flush();
        List<AcCourseSlot> saved = slots.saveAll(next);
        return saved.stream().sorted(java.util.Comparator.comparingInt((AcCourseSlot s) -> s.getDayOfWeek())
                .thenComparing(AcCourseSlot::getStartTime)).map(CourseService::slotView).toList();
    }

    // ---- yardimcilar ----

    CourseView detail(AcCourse c) {
        List<SlotView> sv = slots.findTop30ByCourseIdOrderByDayOfWeekAscStartTimeAsc(c.getId()).stream()
                .map(CourseService::slotView).toList();
        return toView(c, sv, enrollments.countByCourseId(c.getId()), sessions.countByCourseId(c.getId()));
    }

    /** Liste: saatler tek sorguda; sayaclar yok (null). */
    List<CourseView> views(List<AcCourse> rows) {
        if (rows.isEmpty()) {
            return List.of();
        }
        Map<Long, List<SlotView>> byCourse = new HashMap<>();
        for (AcCourseSlot s : slots.ofCourses(rows.stream().map(AcCourse::getId).toList(),
                PageRequest.of(0, rows.size() * MAX_SLOTS))) {
            byCourse.computeIfAbsent(s.getCourseId(), k -> new ArrayList<>()).add(slotView(s));
        }
        return rows.stream().map(c -> toView(c, byCourse.getOrDefault(c.getId(), List.of()), null, null)).toList();
    }

    static CourseView toView(AcCourse c, List<SlotView> slotViews, Long enrolled, Long sessionCount) {
        Integer v = c.getAbsenceLimitValue() == null ? null : c.getAbsenceLimitValue().intValue();
        String t = c.getAbsenceLimitType() == null ? null : c.getAbsenceLimitType().name();
        return new CourseView(c.getId(), c.getCode(), c.getName(), c.getTerm(), c.getFaculty(), c.getDepartment(), c.getGrade(),
                limitOf(c), t, v, c.getStatus().name(),
                c.getPlannedSessions() == null ? null : c.getPlannedSessions().intValue(), slotViews, enrolled, sessionCount, c.getCreatedAt());
    }

    static LimitView limitOf(AcCourse c) {
        if (c.getAbsenceLimitType() == null || c.getAbsenceLimitValue() == null) {
            return new LimitView(null, null, null);
        }
        Integer value = c.getAbsenceLimitValue().intValue();
        return new LimitView(c.getAbsenceLimitType().name(), value, AbsencePolicy.allowedAbsences(c.getAbsenceLimitType(), value,
                c.getPlannedSessions() == null ? null : c.getPlannedSessions().intValue()));
    }

    static SlotView slotView(AcCourseSlot s) {
        return new SlotView(s.getId(), s.getDayOfWeek(), s.getStartTime().toString().substring(0, 5),
                s.getEndTime().toString().substring(0, 5), s.getRoom());
    }

    private static LocalTime time(String v, String field) {
        if (v == null || !HHMM.matcher(v.trim()).matches()) {
            throw AcErrors.invalid(field);
        }
        return LocalTime.parse(v.trim());
    }

    /** NONE siniri kaldirir; COUNT 1..365, PERCENT 1..100. Tur verilmeden yalniz deger verilirse mevcut tur korunur. */
    private static void applyLimit(AcCourse c, String type, Integer value) {
        if (type == null && value == null) {
            return;
        }
        String t = type == null ? (c.getAbsenceLimitType() == null ? null : c.getAbsenceLimitType().name())
                : type.trim().toUpperCase(Locale.ROOT);
        if ("NONE".equals(t)) {
            c.setAbsenceLimitType(null);
            c.setAbsenceLimitValue(null);
            return;
        }
        AcCourse.LimitType lt;
        try {
            lt = AcCourse.LimitType.valueOf(t == null ? "" : t);
        } catch (IllegalArgumentException e) {
            throw AcErrors.invalid("absenceLimitType");
        }
        int max = lt == AcCourse.LimitType.PERCENT ? 100 : 365;
        Integer val = value != null ? value : (c.getAbsenceLimitValue() == null ? null : c.getAbsenceLimitValue().intValue());
        if (val == null || val < 1 || val > max) {
            throw AcErrors.invalid("absenceLimitValue");
        }
        c.setAbsenceLimitType(lt);
        c.setAbsenceLimitValue(val.shortValue());
    }

    /** Hedef kitle katalogla uyumlu olmali (toplu kayit ogrenci profilindeki bolum adiyla eslesir). */
    private void validateAudience(String faculty, String department, String grade) {
        if (grade != null && !catalog.isValidGrade(grade)) {
            throw AcErrors.invalid("grade");
        }
        if (faculty != null && !catalog.isValidFaculty(faculty)) {
            throw AcErrors.invalid("faculty");
        }
        boolean deptOk = faculty != null ? catalog.isValid(faculty, department)
                : catalog.catalog().faculties().stream().anyMatch(f -> f.departments().stream().anyMatch(d -> d.name().equals(department)));
        if (!deptOk) {
            throw AcErrors.invalid("department");
        }
    }
}
