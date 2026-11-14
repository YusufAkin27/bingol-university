package edu.bingol.backend.academician;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Tek kapi: /api/academician/** servisleri (me ve apply haric) once buradan gecer. Onayli olmayan 403
 * ACADEMICIAN_NOT_APPROVED; baskasinin ders/oturumu 404 (varligi sizmaz).
 */
@Component
public class AcademicianGuard {

    private final AcademicianRepository academicians;
    private final AcCourseRepository courses;
    private final AcSessionRepository sessions;

    public AcademicianGuard(AcademicianRepository academicians, AcCourseRepository courses, AcSessionRepository sessions) {
        this.academicians = academicians;
        this.courses = courses;
        this.sessions = sessions;
    }

    @Transactional(readOnly = true)
    public Academician requireApproved(Long userId) {
        return academicians.findById(userId).filter(a -> a.getStatus() == Academician.Status.APPROVED)
                .orElseThrow(AcErrors::notApproved);
    }

    /** Onayli akademisyen + dersin sahibi; degilse 404. */
    @Transactional(readOnly = true)
    public AcCourse ownCourse(Long userId, Long courseId) {
        requireApproved(userId);
        return courses.findByIdAndOwnerId(courseId, userId).orElseThrow(AcErrors::courseNotFound);
    }

    /** Onayli akademisyen + oturumun dersinin sahibi; degilse 404. */
    @Transactional(readOnly = true)
    public AcSession ownSession(Long userId, Long sessionId) {
        requireApproved(userId);
        AcSession s = sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound);
        courses.findByIdAndOwnerId(s.getCourseId(), userId).orElseThrow(AcErrors::sessionNotFound);
        return s;
    }
}
