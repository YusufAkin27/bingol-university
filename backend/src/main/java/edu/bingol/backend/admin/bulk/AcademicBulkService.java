package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.academic.AcademicCalendarService;
import edu.bingol.backend.academic.DepartmentAnnouncementService;
import edu.bingol.backend.academic.ExamService;
import edu.bingol.backend.admin.bulk.BulkDtos.AcademicAction;
import edu.bingol.backend.admin.bulk.BulkDtos.AcademicEntity;
import edu.bingol.backend.admin.bulk.BulkDtos.Report;
import edu.bingol.backend.admin.bulk.BulkSupport.Tally;
import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Akademik takvim / sinav programi / bolum duyurusu toplu yayinla - kaldir - sil. Mevcut servis metotlari KULLANILIR
 * (her biri kendi @Transactional'i); bu sinif @Transactional degildir: kismi basari. Yayinlanan ve bildirimi acik
 * duyurular, servisin kendi kurali geregi (bir kez) hedef kitleye bildirim gonderir.
 */
@Service
public class AcademicBulkService {

    private static final Logger log = LoggerFactory.getLogger(AcademicBulkService.class);

    private final AcademicCalendarService calendar;
    private final ExamService exams;
    private final DepartmentAnnouncementService announcements;

    public AcademicBulkService(AcademicCalendarService calendar, ExamService exams,
                               DepartmentAnnouncementService announcements) {
        this.calendar = calendar;
        this.exams = exams;
        this.announcements = announcements;
    }

    public Report run(AcademicEntity entity, AcademicAction action, List<Long> ids) {
        Tally t = new Tally();
        for (Long id : ids) {
            try {
                if (action == AcademicAction.DELETE) {
                    delete(entity, id);
                    t.done(id);
                } else {
                    boolean target = action == AcademicAction.PUBLISH;
                    if (published(entity, id) == target) {
                        t.skipped(id, "ALREADY_DONE");
                    } else {
                        setPublished(entity, id, target);
                        t.done(id);
                    }
                }
            } catch (ApiException e) {
                if (e.status() == HttpStatus.NOT_FOUND) {
                    t.skipped(id, "NOT_FOUND");
                } else {
                    t.failed(id, e.code());
                }
            } catch (RuntimeException e) {
                log.warn("Toplu akademik islem hatasi: {} id={} {}", entity, id, e.toString());
                t.failed(id, "INTERNAL_ERROR");
            }
        }
        return t.report();
    }

    private boolean published(AcademicEntity entity, Long id) {
        return switch (entity) {
            case CALENDAR -> calendar.adminGet(id).published();
            case EXAM -> exams.adminGet(id).published();
            case ANNOUNCEMENT -> announcements.adminGet(id).published();
        };
    }

    private void setPublished(AcademicEntity entity, Long id, boolean value) {
        switch (entity) {
            case CALENDAR -> calendar.setPublished(id, value);
            case EXAM -> exams.adminPublish(id, value);
            case ANNOUNCEMENT -> announcements.setPublished(id, value);
        }
    }

    private void delete(AcademicEntity entity, Long id) {
        switch (entity) {
            case CALENDAR -> calendar.delete(id);
            case EXAM -> exams.adminDelete(id);
            case ANNOUNCEMENT -> announcements.delete(id);
        }
    }
}
