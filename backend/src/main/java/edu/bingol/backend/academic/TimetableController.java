package edu.bingol.backend.academic;

import edu.bingol.backend.academic.AcademicDtos.CourseRequest;
import edu.bingol.backend.academic.AcademicDtos.CourseView;
import edu.bingol.backend.academic.AcademicDtos.ExamRequest;
import edu.bingol.backend.academic.AcademicDtos.ExamView;
import edu.bingol.backend.academic.AcademicDtos.ExamsView;
import edu.bingol.backend.academic.AcademicDtos.ImportRequest;
import edu.bingol.backend.academic.AcademicDtos.ImportResult;
import edu.bingol.backend.academic.AcademicDtos.OfficialExamsView;
import edu.bingol.backend.academic.AcademicDtos.RemindersView;
import edu.bingol.backend.academic.AcademicDtos.SemesterRequest;
import edu.bingol.backend.academic.AcademicDtos.SemesterView;
import edu.bingol.backend.academic.AcademicDtos.SemestersView;
import edu.bingol.backend.academic.AcademicDtos.TimetableView;
import edu.bingol.backend.academic.AcademicDtos.TodayView;
import edu.bingol.backend.academic.AcademicDtos.WeekView;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Ders programi + kisisel/resmi sinav uclari: yalniz HTTP eslemesi ve hiz siniri. */
@RestController
@RequestMapping("/api")
public class TimetableController {

    private final TimetableService service;
    private final ExamService exams;
    private final RateLimiter limiter;

    public TimetableController(TimetableService service, ExamService exams, RateLimiter limiter) {
        this.service = service;
        this.exams = exams;
        this.limiter = limiter;
    }

    private Long read() {
        Long uid = CurrentUser.id();
        limiter.check("acd:read:" + uid, 120, Duration.ofMinutes(1));
        return uid;
    }

    private Long write() {
        Long uid = CurrentUser.id();
        limiter.check("acd:write:" + uid, 60, Duration.ofHours(1));
        return uid;
    }

    // ---- dersler ----

    @GetMapping("/timetable")
    public TimetableView timetable(@RequestParam(required = false) Long semesterId) {
        return service.timetable(read(), semesterId);
    }

    @PostMapping("/timetable/courses")
    @ResponseStatus(HttpStatus.CREATED)
    public CourseView create(@RequestBody CourseRequest req) {
        return service.createCourse(write(), req);
    }

    @PatchMapping("/timetable/courses/{id}")
    public CourseView update(@PathVariable Long id, @RequestBody CourseRequest req) {
        return service.updateCourse(write(), id, req);
    }

    @DeleteMapping("/timetable/courses/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.deleteCourse(write(), id);
    }

    @PostMapping("/timetable/import")
    @ResponseStatus(HttpStatus.CREATED)
    public ImportResult importCourses(@RequestBody ImportRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("acd:import:" + uid, 5, Duration.ofHours(1));
        return service.importCourses(uid, req);
    }

    @GetMapping("/timetable/today")
    public TodayView today(@RequestParam(required = false) String date) {
        return service.today(read(), date);
    }

    @GetMapping("/timetable/week")
    public WeekView week(@RequestParam(required = false) String date) {
        return service.week(read(), date);
    }

    @GetMapping("/timetable/reminders")
    public RemindersView reminders(@RequestParam(defaultValue = "7") int days) {
        return service.reminders(read(), days);
    }

    @GetMapping("/timetable/export.ics")
    public ResponseEntity<byte[]> exportIcs(@RequestParam(required = false) Long semesterId) {
        Long uid = CurrentUser.id();
        limiter.check("acd:ics:" + uid, 20, Duration.ofHours(1));
        byte[] body = service.exportIcs(uid, semesterId).getBytes(StandardCharsets.UTF_8);
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "calendar", StandardCharsets.UTF_8))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"bu-ders-programi.ics\"")
                .body(body);
    }

    // ---- donemler ----

    @GetMapping("/timetable/semesters")
    public SemestersView semesters() {
        return service.semesters(read());
    }

    @PostMapping("/timetable/semesters")
    @ResponseStatus(HttpStatus.CREATED)
    public SemesterView createSemester(@RequestBody SemesterRequest req) {
        return service.createSemester(write(), req);
    }

    @PostMapping("/timetable/semesters/from-official")
    @ResponseStatus(HttpStatus.CREATED)
    public SemesterView fromOfficial() {
        return service.semesterFromOfficial(write());
    }

    @PatchMapping("/timetable/semesters/{id}")
    public SemesterView updateSemester(@PathVariable Long id, @RequestBody SemesterRequest req) {
        return service.updateSemester(write(), id, req);
    }

    @DeleteMapping("/timetable/semesters/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteSemester(@PathVariable Long id) {
        service.deleteSemester(write(), id);
    }

    // ---- sinavlar ----

    @PostMapping("/timetable/exams")
    @ResponseStatus(HttpStatus.CREATED)
    public ExamView createExam(@RequestBody ExamRequest req) {
        return exams.create(write(), req);
    }

    @GetMapping("/timetable/exams")
    public ExamsView listExams(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return new ExamsView(exams.list(read(), from, to));
    }

    /** Sabit yol, {id} eslemesinden onceliklidir. */
    @GetMapping("/timetable/exams/upcoming")
    public ExamsView upcoming(@RequestParam(defaultValue = "30") int days) {
        return new ExamsView(exams.upcoming(read(), days));
    }

    @PatchMapping("/timetable/exams/{id}")
    public ExamView updateExam(@PathVariable Long id, @RequestBody ExamRequest req) {
        return exams.update(write(), id, req);
    }

    @DeleteMapping("/timetable/exams/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteExam(@PathVariable Long id) {
        exams.delete(write(), id);
    }

    @GetMapping("/exams/official")
    public OfficialExamsView official(@RequestParam(defaultValue = "mine") String scope) {
        return exams.official(read(), "all".equalsIgnoreCase(scope));
    }
}
