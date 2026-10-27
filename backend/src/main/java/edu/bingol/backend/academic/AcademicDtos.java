package edu.bingol.backend.academic;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/** Akademik modul istek/yanit kayitlari. Sozlesme: docs/API_CONTRACTS_V2.md "Akademik". */
public final class AcademicDtos {

    private AcademicDtos() {}

    // ---- ders programi ----
    public record SessionIn(Integer dayOfWeek, String start, String end, String room) {}

    public record SessionView(Long id, int dayOfWeek, String start, String end, String room) {}

    /** POST ve PATCH ortak; PATCH'te null = degismez, "" = alani temizle. */
    public record CourseRequest(String name, String code, String instructor, String color, String note,
                                Long semesterId, Boolean force, List<SessionIn> sessions,
                                Integer dayOfWeek, String startTime, String endTime, String room) {}

    public record CourseView(Long id, String name, String code, String instructor, String color, String note,
                             Long semesterId, List<SessionView> sessions) {}

    public record SemesterRequest(String name, String startDate, String endDate, Boolean current) {}

    public record SemesterView(Long id, String name, String startDate, String endDate, boolean current) {}

    public record OfficialSemester(String name, String startDate, String endDate) {}

    public record SemestersView(List<SemesterView> items, OfficialSemester officialCurrent) {}

    public record TimetableView(SemesterView semester, List<CourseView> courses) {}

    public record ImportRequest(Long semesterId, Boolean replace, Boolean force, List<CourseRequest> courses) {}

    public record ImportResult(int created, List<CourseView> courses) {}

    public record DayItem(Long courseId, Long sessionId, String name, String code, String instructor, String room,
                          String color, String start, String end, String status) {}

    public record NextItem(String date, Long courseId, Long sessionId, String name, String start, String end,
                           String room, String color, long minutesUntil) {}

    public record TodayView(String date, int dayOfWeek, List<DayItem> items, NextItem next) {}

    public record WeekDay(int dayOfWeek, String date, List<DayItem> items) {}

    public record WeekView(String weekStart, List<WeekDay> days) {}

    public record ReminderSession(Long courseId, Long sessionId, String name, String room, String startsAt, String endsAt) {}

    public record RemindersView(String generatedAt, List<ReminderSession> sessions, List<ExamView> exams) {}

    // ---- sinavlar ----
    public record ExamRequest(Long courseId, String title, String type, String startsAt, String endsAt,
                              String room, String note) {}

    public record ExamView(Long id, Long courseId, String courseName, String title, String type, String startsAt,
                           String endsAt, String room, String note) {}

    public record ExamsView(List<ExamView> items) {}

    public record OfficialExamView(Long id, String title, String type, String term, String courseCode, String faculty,
                                   String department, String grade, String startsAt, String endsAt, String room,
                                   String note) {}

    public record OfficialExamsView(List<OfficialExamView> items, boolean profileComplete) {}

    /** Yonetici: resmi sinav programi. */
    public record ExamScheduleRequest(String title, String type, String term, String courseCode, String faculty,
                                      String department, String grade, String startsAt, String endsAt, String room,
                                      String note, Boolean published) {}

    public record AdminExamScheduleView(Long id, String title, String type, String term, String courseCode,
                                        String faculty, String department, String grade, String startsAt,
                                        String endsAt, String room, String note, boolean published) {}

    // ---- akademik takvim ----
    public record AcademicEventView(Long id, String kind, String title, String startsAt, String endsAt, boolean allDay,
                                    String scopeDepartment, String note) {}

    public record CalendarView(String from, String to, List<AcademicEventView> items) {}

    public record AcademicEventRequest(String kind, String title, String startsAt, String endsAt, Boolean allDay,
                                       String scopeDepartment, String note, Boolean published) {}

    public record AdminAcademicEventView(Long id, String kind, String title, String startsAt, String endsAt,
                                         boolean allDay, String scopeDepartment, String note, boolean published) {}

    public record EventImportRequest(String text, Boolean publish) {}

    public record ImportError(int line, String message) {}

    public record EventImportResult(int created, List<ImportError> errors) {}

    // ---- duyurular ----
    public record AnnouncementView(Long id, String title, String body, boolean bodyTruncated, String department,
                                   String faculty, String grade, boolean pinned, String publishAt, String expiresAt,
                                   String attachmentUrl, boolean read, String createdAt) {}

    public record AnnouncementPage(List<AnnouncementView> items, String nextCursor) {}

    public record AnnouncementRequest(String title, String body, String department, String faculty, String grade,
                                      Boolean pinned, String publishAt, String expiresAt, String attachmentUrl,
                                      Boolean published, @JsonProperty("notify") Boolean notifyUsers) {}

    public record AdminAnnouncementView(Long id, String title, String body, String department, String faculty,
                                        String grade, boolean pinned, String publishAt, String expiresAt,
                                        String attachmentUrl, boolean published, @JsonProperty("notify") boolean notifyUsers, String notifiedAt,
                                        Long createdBy, long readCount, String createdAt) {}

    public record CountView(long count) {}

    public record Page<T>(List<T> items, int page, int size, long total) {}
}
