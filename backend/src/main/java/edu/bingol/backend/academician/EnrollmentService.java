package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.AddedResult;
import edu.bingol.backend.academician.AcademicianDtos.EnrollmentView;
import edu.bingol.backend.academician.AcademicianDtos.StudentView;
import edu.bingol.backend.academician.StudentDirectory.Person;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/** Ogrenci rehberi aramasi ve derse kayit (tek tek, toplu, cikarma). Kayit satiri tekildir: yaris tekil kisitla cozulur. */
@Service
public class EnrollmentService {

    /** Toplu kayitta bir seferde eklenebilecek en cok ogrenci; fazlasi 422 (sessiz kirpma yok). */
    public static final int BULK_CAP = 500;
    /** Bir dersin toplam kayit ust siniri (liste ve rapor sinirli kalsin). */
    public static final int MAX_ENROLLED = 2000;

    private final AcademicianGuard guard;
    private final StudentDirectory directory;
    private final AcEnrollmentRepository enrollments;
    private final AcademicianNotifier notifier;
    private final TransactionTemplate tx;

    public EnrollmentService(AcademicianGuard guard, StudentDirectory directory, AcEnrollmentRepository enrollments,
                             AcademicianNotifier notifier, PlatformTransactionManager tm) {
        this.guard = guard;
        this.directory = directory;
        this.enrollments = enrollments;
        this.notifier = notifier;
        this.tx = new TransactionTemplate(tm);
    }

    public CursorPage<StudentView> searchStudents(Long userId, String q, String faculty, String department, String grade,
                                                  Long cursor, int size) {
        guard.requireApproved(userId);
        int s = CursorPage.clampSize(size);
        List<Person> rows = directory.search(q, faculty, department, grade, cursor == null ? 0 : cursor, s + 1);
        return CursorPage.of(rows, s, Person::id, Person::view);
    }

    public List<EnrollmentView> list(Long userId, Long courseId) {
        guard.ownCourse(userId, courseId);
        List<AcEnrollment> rows = enrollments.ofCourse(courseId, PageRequest.of(0, MAX_ENROLLED));
        Map<Long, Person> people = directory.labels(rows.stream().map(AcEnrollment::getStudentId).toList());
        List<EnrollmentView> out = new ArrayList<>();
        for (AcEnrollment e : rows) {
            Person p = people.get(e.getStudentId());
            out.add(new EnrollmentView(e.getStudentId(), p == null ? null : p.displayName(), p == null ? null : p.studentNo(),
                    p == null ? null : p.faculty(), p == null ? null : p.department(), p == null ? null : p.grade(), e.getAddedAt()));
        }
        out.sort(Comparator.comparing(EnrollmentView::displayName, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)));
        return out;
    }

    public AddedResult add(Long userId, Long courseId, List<Long> studentIds) {
        AcCourse c = guard.ownCourse(userId, courseId);
        Set<Long> ids = new LinkedHashSet<>();
        for (Long id : studentIds == null ? List.<Long>of() : studentIds) {
            if (id == null) {
                throw AcErrors.invalid("studentIds");
            }
            ids.add(id);
        }
        return enroll(userId, c, directory.eligibleByIds(ids).keySet());
    }

    /** Bolum (+ sinif) ogrencilerinin tamamini ekler; eslesen sayi {@link #BULK_CAP}'i asarsa hicbiri eklenmez (422). */
    public AddedResult bulk(Long userId, Long courseId, String department, String grade) {
        AcCourse c = guard.ownCourse(userId, courseId);
        String dept = AcademicianService.clean(department, "department", 160, true);
        List<Person> match = directory.byDepartment(dept, AcademicianService.clean(grade, "grade", 8, false), BULK_CAP + 1);
        if (match.size() > BULK_CAP) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "AC_BULK_TOO_LARGE",
                    "Eşleşen öğrenci sayısı " + BULK_CAP + " sınırını aşıyor; sınıf süzgeci ekleyin.", String.valueOf(BULK_CAP));
        }
        return enroll(userId, c, match.stream().map(Person::id).toList());
    }

    public void remove(Long userId, Long courseId, Long studentId) {
        guard.ownCourse(userId, courseId);
        tx.executeWithoutResult(s -> enrollments.remove(courseId, studentId));
    }

    private AddedResult enroll(Long userId, AcCourse c, java.util.Collection<Long> candidates) {
        if (candidates.isEmpty()) {
            return new AddedResult(0);
        }
        Set<Long> already = new LinkedHashSet<>(enrollments.alreadyEnrolled(c.getId(), candidates));
        List<Long> fresh = candidates.stream().filter(id -> !already.contains(id)).toList();
        if (enrollments.countByCourseId(c.getId()) + fresh.size() > MAX_ENROLLED) {
            throw new ApiException(HttpStatus.CONFLICT, "AC_ENROLLMENT_LIMIT",
                    "Bir derse en fazla " + MAX_ENROLLED + " öğrenci eklenebilir.", String.valueOf(MAX_ENROLLED));
        }
        List<Long> added = new ArrayList<>();
        for (Long id : fresh) {
            if (insert(c.getId(), id)) {
                added.add(id);
            }
        }
        String who = guard.requireApproved(userId).fullName();
        notifier.enrolled(c.getId(), c.getName(), who, added);
        return new AddedResult(added.size());
    }

    /** Tekil kisit ihlali (es zamanli ekleme) hata degil: satir zaten var demektir. */
    private boolean insert(Long courseId, Long studentId) {
        try {
            return Boolean.TRUE.equals(tx.execute(s -> {
                AcEnrollment e = new AcEnrollment();
                e.setCourseId(courseId);
                e.setStudentId(studentId);
                e.setAddedAt(Instant.now());
                enrollments.saveAndFlush(e);
                return true;
            }));
        } catch (DataIntegrityViolationException dup) {
            return false;
        }
    }
}
