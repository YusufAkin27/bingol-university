package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import edu.bingol.backend.academician.AcademicianDtos.NoticeRequest;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.dbmaint.DbMaintenanceJob;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/** Duzeltme turu 1: sayimlar (gec kayit, canli, sayilmayan, izinli, planlanan), oturum yasam dongusu, suistimal/guvenlik, kucuk API eklemeleri. */
class AcademicianFixRound1MvcTest extends AcademicianMvcBase {

    @Autowired AcNoticeRepository noticeRepo;
    @Autowired AcNoticeFileRepository fileRepo;
    @Autowired AcScanRequestRepository scanRequests;
    @Autowired NoticeFileService noticeFiles;
    @Autowired PrivateMediaStore store;
    @Autowired DbMaintenanceJob maintenance;
    @Autowired I18n i18n;
    @Autowired AcademicianUploadAdvice uploadAdvice;
    @Autowired List<edu.bingol.backend.export.DataExporter> exporters;

    private static final Instant FUTURE = Instant.now().plusSeconds(86400 * 3);

    // ---- yardimcilar ----

    private long sessionOn(User l, long courseId, int daysAgo) {
        return call(l, postJson("/api/academician/courses/" + courseId + "/sessions",
                obj().put("lessonDate", LocalDate.now().minusDays(daysAgo).toString())), 201).get("id").asLong();
    }

    private void close(User l, long sid) {
        call(l, postJson("/api/academician/sessions/" + sid + "/close", null), 200);
    }

    private void markPresent(User l, long sid, User s) {
        call(l, put("/api/academician/sessions/" + sid + "/records/" + s.getId()), 200);
    }

    private JsonNode excuse(User l, long sid, User s) {
        return call(l, put("/api/academician/sessions/" + sid + "/records/" + s.getId()).contentType("application/json")
                .content("{\"excused\":true}"), 200);
    }

    private void remove(User l, long sid, User s) {
        call(l, delete("/api/academician/sessions/" + sid + "/records/" + s.getId()), 204);
    }

    private JsonNode matrix(User l, long courseId) {
        return call(l, get("/api/academician/courses/" + courseId + "/attendance"), 200);
    }

    private static JsonNode row(JsonNode m, User s) {
        for (JsonNode r : m.get("students")) {
            if (r.get("studentId").asLong() == s.getId()) {
                return r;
            }
        }
        throw new AssertionError("satir yok " + s.getId());
    }

    private JsonNode patchCourse(User l, long courseId, String json) {
        return call(l, patch("/api/academician/courses/" + courseId).contentType("application/json").content(json), 200);
    }

    private JsonNode myCourse(User s) {
        return call(s, get("/api/my-courses"), 200).get(0);
    }

    private long warnedLevel(long courseId, User s) {
        return enrollRepo.ofCourse(courseId, org.springframework.data.domain.PageRequest.of(0, 50)).stream()
                .filter(e -> e.getStudentId().equals(s.getId())).findFirst().orElseThrow().getWarnedLevel();
    }

    // ================= B1 / B2: gec kayit ve canli oturum =================

    @Test
    void lateEnrolledStudentIsNotCountedAbsentForEarlierSessionsAndNotWarned() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User early = student("Erken");
        enrol(l, courseId, early);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":2}");
        long[] sids = new long[3];
        for (int i = 0; i < 3; i++) {
            sids[i] = sessionOn(l, courseId, 3 - i);
            markPresent(l, sids[i], early);
            close(l, sids[i]);
        }
        User late = student("Gec Eklenen");
        enrol(l, courseId, late);
        JsonNode r = row(matrix(l, courseId), late);
        for (long sid : sids) {
            assertEquals("NOT_ENROLLED_YET", r.get("marks").get(String.valueOf(sid)).asText());
        }
        assertEquals(0, r.get("absentCount").asInt());
        assertEquals(0, r.get("sessionCount").asInt());
        assertFalse(r.get("overLimit").asBoolean());
        assertEquals(0, countTitle(late, "notif.academician.absenceExceeded.title"));
        assertEquals(0, countTitle(late, "notif.academician.absenceWarning.title"));
        JsonNode mine = myCourse(late);
        assertEquals(0, mine.get("sessionCount").asInt());
        assertEquals(0, mine.get("absentCount").asInt());
        // yeni oturum: gec eklenen icin SAYILIR
        long next = sessionOn(l, courseId, 0);
        close(l, next);
        assertEquals("ABSENT", row(matrix(l, courseId), late).get("marks").get(String.valueOf(next)).asText());
        assertEquals(1, row(matrix(l, courseId), late).get("sessionCount").asInt());
        assertEquals(1, row(matrix(l, courseId), late).get("absentCount").asInt());
        // csv metni
        String csv = new String(raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv")).getContentAsByteArray(),
                java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.contains("Kayıtlı değildi"), csv);
    }

    @Test
    void liveSessionDoesNotCountAnywhereAndIsFlaggedLive() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Henuz Okutmadi");
        enrol(l, courseId, s);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":1}");
        long sid = sessionOn(l, courseId, 0); // canli
        JsonNode m = matrix(l, courseId);
        assertTrue(m.get("sessions").get(0).get("live").asBoolean());
        JsonNode r = row(m, s);
        assertEquals("ABSENT", r.get("marks").get(String.valueOf(sid)).asText()); // gecici
        assertEquals(0, r.get("absentCount").asInt());
        assertEquals(0, r.get("sessionCount").asInt());
        assertFalse(r.get("overLimit").asBoolean());
        assertFalse(r.get("atRisk").asBoolean());
        JsonNode mine = myCourse(s);
        assertEquals(0, mine.get("sessionCount").asInt());
        assertEquals(0, mine.get("absentCount").asInt());
        assertFalse(mine.get("overLimit").asBoolean());
        assertEquals(0, countTitle(s, "notif.academician.absenceExceeded.title"));
        close(l, sid);
        assertFalse(matrix(l, courseId).get("sessions").get(0).get("live").asBoolean());
        assertTrue(row(matrix(l, courseId), s).get("overLimit").asBoolean());
        assertEquals(1, myCourse(s).get("absentCount").asInt());
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title"));
    }

    // ================= B3 / B4: acma ve silme =================

    @Test
    void openingWithoutSlotAlwaysCreatesANewSessionExceptDoubleClick() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        JsonNode first = call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj()), 201);
        assertFalse(first.get("reused").asBoolean());
        // cift tiklama (10 sn icinde, hala canli, slotsuz): ayni oturum
        JsonNode dbl = call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj()), 201);
        assertEquals(first.get("id").asLong(), dbl.get("id").asLong());
        assertTrue(dbl.get("reused").asBoolean());
        markPresent(l, first.get("id").asLong(), s);
        close(l, first.get("id").asLong());
        // ayni gun ikinci ders: onceki oturum 10 sn'den eski -> YENI oturum, kimse "var" gelmez
        AcSession a = sessionRepo.findById(first.get("id").asLong()).orElseThrow();
        a.setOpenedAt(Instant.now().minusSeconds(120));
        sessionRepo.save(a);
        JsonNode second = call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj()), 201);
        assertNotEquals(first.get("id").asLong(), second.get("id").asLong());
        assertFalse(second.get("reused").asBoolean());
        assertEquals(0, second.get("presentCount").asInt());
        assertEquals("CLOSED", call(l, get("/api/academician/sessions/" + first.get("id").asLong()), 200).get("status").asText());
        // slot verilirse ayni gun+slot yeniden kullanilir
        long slotId = call(l, put("/api/academician/courses/" + courseId + "/slots").contentType("application/json")
                .content("[{\"dayOfWeek\":1,\"startTime\":\"09:00\",\"endTime\":\"10:00\"}]"), 200).get(0).get("id").asLong();
        JsonNode s1 = call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj().put("slotId", slotId)), 201);
        assertFalse(s1.get("reused").asBoolean());
        close(l, s1.get("id").asLong());
        JsonNode s2 = call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj().put("slotId", slotId)), 201);
        assertEquals(s1.get("id").asLong(), s2.get("id").asLong());
        assertTrue(s2.get("reused").asBoolean());
    }

    @Test
    void notifiedFlagIsTrueOnlyWhenThePushWasActuallySent() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        assertFalse(call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj()), 201).get("notified").asBoolean());
        JsonNode withNotify = call(l, postJson("/api/academician/courses/" + courseId + "/sessions",
                obj().put("notify", true).put("lessonDate", LocalDate.now().minusDays(1).toString())), 201);
        assertTrue(withNotify.get("notified").asBoolean());
        assertEquals(1, countTitle(s, "notif.academician.attendanceStarted.title"));
        // 10 dk kurali bastirir
        JsonNode again = call(l, postJson("/api/academician/courses/" + courseId + "/sessions",
                obj().put("notify", true).put("lessonDate", LocalDate.now().minusDays(2).toString())), 201);
        assertFalse(again.get("notified").asBoolean());
        assertEquals(1, countTitle(s, "notif.academician.attendanceStarted.title"));
    }

    @Test
    void lecturerCanDeleteASessionAndWarningsDropSilently() throws Exception {
        User l = lecturer("Hoca");
        User other = lecturer("Baska");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":1}");
        long mistake = sessionOn(l, courseId, 1);
        close(l, mistake);
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertEquals(2, warnedLevel(courseId, s));
        // baskasi silemez
        expectError(other, delete("/api/academician/sessions/" + mistake), 404, "AC_SESSION_NOT_FOUND");
        // bekleyen istek + kayit ile birlikte silinir
        AcScanRequest req = new AcScanRequest();
        req.setSessionId(mistake);
        req.setStudentId(900_000_001L);
        req.setScannedAt(Instant.now());
        scanRequests.save(req);
        call(l, delete("/api/academician/sessions/" + mistake), 204);
        assertTrue(sessionRepo.findById(mistake).isEmpty());
        assertEquals(0, scanRequests.findAll().stream().filter(r -> r.getSessionId().equals(mistake)).count());
        assertEquals(0, attendRepo.findAll().stream().filter(a -> a.getSessionId().equals(mistake)).count());
        assertEquals(0, matrix(l, courseId).get("sessions").size());
        // duzey sessizce dustu: ek bildirim yok; yeniden asinca tekrar bildirilir
        assertEquals(0, warnedLevel(courseId, s));
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title"));
        long real = sessionOn(l, courseId, 0);
        close(l, real);
        assertEquals(2, countTitle(s, "notif.academician.absenceExceeded.title"));
        call(l, delete("/api/academician/sessions/" + real), 204); // kapali/herhangi durum
    }

    // ================= B5 / B6: yazi ve yeniden acma =================

    @Test
    void csvSaysReachedAtEqualityAndExceededBeyondAndReopenDoesNotDuplicateWarnings() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":2}");
        long s1 = sessionOn(l, courseId, 3);
        close(l, s1);
        long s2 = sessionOn(l, courseId, 2);
        close(l, s2);
        String csv2 = new String(raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv")).getContentAsByteArray(),
                java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv2.contains("Sınıra ulaştı"), csv2);
        assertFalse(csv2.contains("Sınır aşıldı"), csv2);
        long s3 = sessionOn(l, courseId, 1);
        close(l, s3);
        String csv3 = new String(raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv")).getContentAsByteArray(),
                java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv3.contains("Sınır aşıldı"), csv3);
        // yeniden acma + tekrar kapatma: ayni duzey bir kez daha bildirilmez, warned_level dusmez
        long before = countTitle(s, "notif.academician.absenceExceeded.title");
        assertEquals(2, warnedLevel(courseId, s));
        call(l, postJson("/api/academician/sessions/" + s3 + "/reopen", null), 200);
        assertEquals(2, warnedLevel(courseId, s));
        close(l, s3);
        assertEquals(before, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertEquals(2, warnedLevel(courseId, s));
    }

    // ================= B7 / B8 =================

    @Test
    void removedStudentsAreNotInPresentCountOrLiveListAndRevokedRowIsRestoredOnAccept() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User a = student("Kalan");
        User b = student("Cikarilan");
        enrol(l, courseId, a, b);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        scan(a, code);
        scan(b, code);
        assertEquals(2, live(l, sid).get("presentCount").asInt());
        call(l, delete("/api/academician/courses/" + courseId + "/enrollments/" + b.getId()), 204);
        JsonNode lv = live(l, sid);
        assertEquals(1, lv.get("presentCount").asInt());
        assertEquals(1, lv.get("newRecords").size());
        assertEquals(1, call(l, get("/api/academician/sessions/" + sid), 200).get("presentCount").asInt());
        assertEquals(1, call(l, get("/api/academician/courses/" + courseId + "/sessions"), 200).get(0).get("presentCount").asInt());
        // satir tabloda kalir
        assertTrue(attendRepo.existsBySessionIdAndStudentId(sid, b.getId()));

        // B8: kaldirilmis satir, bekleyen kabulde geri gelir (QR, marked_at = scanned_at)
        User c = student("Kaldirilan");
        enrol(l, courseId, c);
        scan(c, code);
        remove(l, sid, c);
        AcScanRequest req = new AcScanRequest();
        req.setSessionId(sid);
        req.setStudentId(c.getId());
        req.setScannedAt(Instant.parse("2026-01-01T10:00:00Z"));
        scanRequests.save(req);
        JsonNode rec = call(l, post("/api/academician/sessions/" + sid + "/pending/" + c.getId() + "/accept"), 200);
        assertEquals("QR", rec.get("method").asText());
        assertFalse(rec.get("revoked").asBoolean());
        AcAttendance row = attendRepo.findBySessionIdAndStudentId(sid, c.getId()).orElseThrow();
        assertNull(row.getRevokedAt());
        assertEquals(Instant.parse("2026-01-01T10:00:00Z"), row.getMarkedAt());
        assertEquals(AcAttendance.Method.QR, row.getMethod());
    }

    @Test
    void acceptingAPendingScanMakesThatSessionCountForTheLateStudent() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User member = student("Uye");
        enrol(l, courseId, member);
        long sid = openSession(l, courseId);
        User outsider = student("Disaridan");
        assertEquals("PENDING", scan(outsider, code(l, sid)).get("status").asText());
        close(l, sid);
        call(l, post("/api/academician/sessions/" + sid + "/pending/" + outsider.getId() + "/accept"), 200);
        JsonNode r = row(matrix(l, courseId), outsider);
        assertEquals("PRESENT_QR", r.get("marks").get(String.valueOf(sid)).asText());
        assertEquals(1, r.get("sessionCount").asInt());
        assertEquals(1, myCourse(outsider).get("presentCount").asInt());
    }

    // ================= B27 / B29 =================

    @Autowired edu.bingol.backend.common.web.RequestBodyLimitFilter bodyFilter;

    private org.springframework.mock.web.MockHttpServletResponse uploadThroughFilters(User u, long courseId, byte[] bytes) throws Exception {
        var mvcWithFilters = org.springframework.test.web.servlet.setup.MockMvcBuilders.webAppContextSetup(ctx)
                .apply(org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity())
                .addFilters(bodyFilter).build();
        var token = new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(u.getId(), null,
                List.of(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_USER")));
        return mvcWithFilters.perform(multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", "buyuk.pdf", "application/pdf", bytes))
                .with(r -> {
                    r.setContent(new byte[bytes.length + 400]); // gercek istekteki Content-Length (multipart sarmalayici dahil) filtreye gorunsun
                    return r;
                }).with(org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication(token)))
                .andReturn().getResponse();
    }

    @Test
    void largeNoticeFilesPassTheRealBodyLimitFilterAndOversizeGetsTheNoticeCode() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        byte[] header = NoticeFileSnifferTest.pdf();
        byte[] medium = new byte[300 * 1024]; // 64 KB JSON sinirinin cok ustunde
        System.arraycopy(header, 0, medium, 0, header.length);
        var ok = uploadThroughFilters(l, courseId, medium);
        assertEquals(201, ok.getStatus(), ok.getContentAsString());
        assertEquals(medium.length, OM.readTree(ok.getContentAsString()).get("sizeBytes").asLong());
        // etkin siniri 1 bayt asan dosya: filtre gecer (55 MB), servis NOTICE_FILE_TOO_LARGE verir (PAYLOAD_TOO_LARGE degil)
        byte[] over = new byte[(int) noticeFiles.maxFileBytes() + 1];
        System.arraycopy(header, 0, over, 0, header.length);
        var big = uploadThroughFilters(l, courseId, over);
        assertEquals(413, big.getStatus());
        assertEquals("NOTICE_FILE_TOO_LARGE", OM.readTree(big.getContentAsString()).get("code").asText());
    }

    @Test
    void invalidSlotElementsAreStillRejected() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        expectError(l, put("/api/academician/courses/" + courseId + "/slots").contentType("application/json")
                .content("[{\"dayOfWeek\":9,\"startTime\":\"09:00\",\"endTime\":\"10:00\"}]"), 400, "VALIDATION_ERROR");
        expectError(l, put("/api/academician/courses/" + courseId + "/slots").contentType("application/json")
                .content("[{\"dayOfWeek\":1,\"startTime\":\"\",\"endTime\":\"10:00\"}]"), 400, "VALIDATION_ERROR");
        assertEquals(1, call(l, put("/api/academician/courses/" + courseId + "/slots").contentType("application/json")
                .content("[{\"dayOfWeek\":1,\"startTime\":\"09:00\",\"endTime\":\"10:00\"}]"), 200).size());
    }

    // ================= B9 =================

    @Test
    void scanIpLimitIs3000PerMinuteWhileUserLimitStays10() throws Exception {
        User s = student("Ogr");
        raw(s, scanReq("bingol-lesson:1.1.x"));
        verify(limiter, atLeastOnce()).check(eq("attendance-scan:user:" + s.getId()), eq(10), eq(Duration.ofMinutes(1)));
        verify(limiter, atLeastOnce()).check(org.mockito.ArgumentMatchers.startsWith("attendance-scan:ip:"), eq(3000),
                eq(Duration.ofMinutes(1)));
    }

    // ================= B10 =================

    @Test
    void deletedNoticesStillCountTowardsLimitsAndDisappearFromLists() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        String url = "/api/academician/courses/" + courseId + "/notices";
        long id = call(l, postJson(url, obj().put("type", "LESSON_STARTED")), 201).get("id").asLong();
        call(l, delete("/api/academician/notices/" + id), 204);
        expectError(l, postJson(url, obj().put("type", "LESSON_STARTED")), 429, "NOTICE_TOO_FREQUENT"); // olustur-sil dongusu sinirlari asamaz
        assertEquals(0, call(s, get("/api/my-courses/" + courseId + "/notices"), 200).get("items").size());
        assertEquals(0, call(l, get(url), 200).get("items").size());
        assertTrue(noticeRepo.findById(id).orElseThrow().getDeletedAt() != null); // satir kalir
        expectError(l, delete("/api/academician/notices/" + id), 404, "AC_NOTICE_NOT_FOUND"); // ikinci silme
        // gunluk sinir silinenleri de sayar
        for (int i = 0; i < 19; i++) {
            long n = call(l, postJson(url, obj().put("type", "MATERIAL").put("title", "m" + i)), 201).get("id").asLong();
            call(l, delete("/api/academician/notices/" + n), 204);
        }
        expectError(l, postJson(url, obj().put("type", "MATERIAL").put("title", "21.")), 429, "NOTICE_DAILY_LIMIT");
    }

    @Test
    void attachingAFileIsConditionalSoOneFileCannotBelongToTwoNotices() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        JsonNode f = call(l, multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", "a.pdf", "application/pdf", NoticeFileSnifferTest.pdf())), 201);
        long fileId = f.get("id").asLong();
        ObjectNode body = obj().put("type", "MATERIAL").put("title", "Bir");
        body.set("fileIds", OM.createArrayNode().add(fileId));
        long n1 = call(l, postJson("/api/academician/courses/" + courseId + "/notices", body), 201).get("id").asLong();
        // ikinci istek "bekleyen" listesini yarisla gecmis gibi: dogrudan kosullu baglama
        AcNoticeFile stale = fileRepo.findById(fileId).orElseThrow();
        long n2 = call(l, postJson("/api/academician/courses/" + courseId + "/notices", obj().put("type", "MATERIAL").put("title", "Iki")), 201)
                .get("id").asLong();
        ApiException e = assertThrows(ApiException.class, () -> noticeFiles.attach(List.of(stale), n2));
        assertEquals("AC_FIELD_INVALID", e.code());
        assertEquals(n1, fileRepo.findById(fileId).orElseThrow().getNoticeId());
        // normal akista da ikinci baglama 400
        ObjectNode again = obj().put("type", "MATERIAL").put("title", "Uc");
        again.set("fileIds", OM.createArrayNode().add(fileId));
        expectError(l, postJson("/api/academician/courses/" + courseId + "/notices", again), 400, "AC_FIELD_INVALID");
    }

    // ================= B11 =================

    @Test
    void maskedAdminDoesNotSeeStudentNumbersAndAdminReadsAreAudited() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Gizli No");
        enrol(l, courseId, s);
        User full = admin();
        User viewer = admin();
        viewer.setAdminProfile(AdminProfile.VIEWER);
        users.save(viewer);
        String path = "/api/admin/academicians/courses/" + courseId + "/attendance";
        assertEquals(s.getEmail().split("@")[0], row(call(full, get(path), 200), s).get("studentNo").asText());
        JsonNode masked = row(call(viewer, get(path), 200), s);
        assertFalse(masked.toString().contains(s.getEmail().split("@")[0]), masked.toString());
        for (String m : List.of("course", "attendance", "coursesOf")) {
            var method = java.util.Arrays.stream(AcademicianAdminController.class.getDeclaredMethods()).filter(x -> x.getName().equals(m))
                    .findFirst().orElseThrow();
            assertNotNull(method.getAnnotation(AuditRead.class), m);
        }
    }

    // ================= B12 =================

    @Test
    void revokingALecturerClosesTheirLiveSessionsAndScansOnNonApprovedOwnersFail() throws Exception {
        User admin = admin();
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        call(admin, postJson("/api/admin/academicians/" + l.getId() + "/revoke", obj().put("reason", "Ayrildi")), 200);
        assertEquals(AcSession.Status.CLOSED, sessionRepo.findById(sid).orElseThrow().getStatus());
        expectError(s, scanReq(code), 422, "ATTENDANCE_CODE_INVALID");
        // tarama ayrica sahibin onayini sinar (oturum acik kalsa bile)
        User l2 = lecturer("Hoca Iki");
        long c2 = course(l2);
        User s2 = student("Ogr Iki");
        enrol(l2, c2, s2);
        long sid2 = openSession(l2, c2);
        String code2 = code(l2, sid2);
        Academician a = academicianRepo.findById(l2.getId()).orElseThrow();
        a.setStatus(Academician.Status.REJECTED);
        academicianRepo.save(a);
        expectError(s2, scanReq(code2), 422, "ATTENDANCE_CODE_INVALID");
        assertEquals(0, attendRepo.countActive(sid2));
    }

    // ================= B14 / B15 =================

    @Test
    void revokedLecturerCannotEditProfile() throws Exception {
        User admin = admin();
        User l = lecturer("Hoca");
        call(admin, postJson("/api/admin/academicians/" + l.getId() + "/revoke", obj().put("reason", "Ayrildi")), 200);
        expectError(l, put("/api/academician/me").contentType("application/json")
                .content("{\"title\":\"Prof.\",\"firstName\":\"X\",\"lastName\":\"Y\"}"), 403, "ACADEMICIAN_REVOKED");
        assertEquals("Ali", academicianRepo.findById(l.getId()).orElseThrow().getFirstName());
    }

    @Test
    void noticeAndFileIdsDoNotRevealWhoOwnsThem() throws Exception {
        User l = lecturer("Hoca");
        User other = lecturer("Baska");
        long courseId = course(l);
        JsonNode f = call(l, multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", "a.pdf", "application/pdf", NoticeFileSnifferTest.pdf())), 201);
        ObjectNode body = obj().put("type", "MATERIAL").put("title", "M");
        body.set("fileIds", OM.createArrayNode().add(f.get("id").asLong()));
        long noticeId = call(l, postJson("/api/academician/courses/" + courseId + "/notices", body), 201).get("id").asLong();
        long fileId = fileRepo.findAll().stream().filter(x -> x.getNoticeId() != null && x.getNoticeId() == noticeId).findFirst().orElseThrow().getId();
        long missing = 987_654_321L;
        // baskasinin duyurusu ile olmayan duyuru AYNI kodu verir
        expectError(other, delete("/api/academician/notices/" + noticeId), 404, "AC_NOTICE_NOT_FOUND");
        expectError(other, delete("/api/academician/notices/" + missing), 404, "AC_NOTICE_NOT_FOUND");
        expectError(other, get("/api/academician/notices/" + noticeId + "/files/" + fileId), 404, "AC_NOTICE_NOT_FOUND");
        expectError(other, get("/api/academician/notices/" + missing + "/files/" + fileId), 404, "AC_NOTICE_NOT_FOUND");
        // bekleyen dosya: baskasininki / olmayan
        JsonNode pending = call(l, multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", "b.pdf", "application/pdf", NoticeFileSnifferTest.pdf())), 201);
        expectError(other, delete("/api/academician/notice-files/" + pending.get("id").asLong()), 404, "AC_NOTICE_NOT_FOUND");
        expectError(other, delete("/api/academician/notice-files/" + missing), 404, "AC_NOTICE_NOT_FOUND");
    }

    // ================= B16 / B17 / B18 =================

    @Test
    void perLecturerStorageQuotaAndCourseCountCapAreEnforced() throws Exception {
        User l = lecturer("Hoca");
        long c1 = course(l);
        long c2 = course(l);
        AcNoticeFile fat = new AcNoticeFile();
        fat.setCourseId(c2);
        fat.setStorageKey("fake-" + rnd() + ".bin");
        fat.setOriginalName("x.pdf");
        fat.setContentType("application/pdf");
        fat.setSizeBytes(2000L * 1024 * 1024 - 10); // toplam kotaya 10 bayt kaldi (baska ders)
        fat.setUploadedBy(l.getId());
        fileRepo.save(fat);
        JsonNode r = call(l, multipart("/api/academician/courses/" + c1 + "/notice-files")
                .file(new MockMultipartFile("file", "a.pdf", "application/pdf", NoticeFileSnifferTest.pdf())), 422);
        assertEquals("NOTICE_STORAGE_CAP", r.get("code").asText());

        // ders sayisi siniri
        User m = lecturer("Cok Dersli");
        for (int i = 0; i < 59; i++) {
            AcCourse c = new AcCourse();
            c.setOwnerId(m.getId());
            c.setName("D" + i);
            c.setTerm("T");
            c.setDepartment(DEPT);
            courseRepo.save(c);
        }
        course(m); // 60. ders
        expectError(m, postJson("/api/academician/courses", obj().put("name", "61.").put("term", "t").put("faculty", FACULTY)
                .put("department", DEPT)), 422, "AC_COURSE_LIMIT");
    }

    @Test
    void staleUnattachedFilesAreSweptByTheNightlyJob() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        JsonNode f = call(l, multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", "a.pdf", "application/pdf", NoticeFileSnifferTest.pdf())), 201);
        AcNoticeFile row = fileRepo.findById(f.get("id").asLong()).orElseThrow();
        String key = row.getStorageKey();
        assertNotNull(store.read("acnotice", key));
        row.setCreatedAt(Instant.now().minus(Duration.ofHours(30)));
        fileRepo.save(row);
        Map<String, Integer> out = maintenance.runAll();
        assertTrue(out.containsKey("ac_notice_file_pending"), out.toString());
        assertTrue(out.get("ac_notice_file_pending") >= 1, out.toString());
        assertTrue(fileRepo.findById(row.getId()).isEmpty());
        assertNull(store.read("acnotice", key));
    }

    @Test
    void meExposesTheRealUploadLimitsAndOversizeContainerErrorsUseTheNoticeCode() throws Exception {
        User l = lecturer("Hoca");
        JsonNode me = call(l, get("/api/academician/me"), 200);
        long min = Math.min(20L << 20, noticeFiles.maxFileBytes());
        assertEquals(min, me.get("limits").get("noticeFileMaxBytes").asLong());
        assertEquals(5, me.get("limits").get("noticeFilesPerNotice").asInt());
        assertEquals(20L << 20, noticeFiles.maxFileBytes()); // testte multipart varsayilani 52 MB
        // konteyner (multipart) boyut asimi: JSON zarf + NOTICE_FILE_TOO_LARGE
        ResponseEntity<Map<String, String>> resp = uploadAdvice.tooLarge(new MaxUploadSizeExceededException(1));
        assertEquals(413, resp.getStatusCode().value());
        assertEquals("NOTICE_FILE_TOO_LARGE", resp.getBody().get("code"));
        // none-state ve idempotent: gelen yaniti her durumda limits tasir
        assertNotNull(call(student("Baska"), get("/api/academician/me"), 200).get("limits"));
    }

    // ================= B19 =================

    @Test
    void enrolmentAndAbsenceNoticesAreNotTiedToTheExamReminderToggle() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":1}");
        long sid = sessionOn(l, courseId, 1);
        close(l, sid);
        for (String k : List.of("enrolled", "absenceExceeded")) {
            String title = "notif.academician." + k + ".title";
            List<Notification> hits = notificationsOf(s).stream().filter(n -> title.equals(n.getTitle())).toList();
            assertEquals(1, hits.size(), k);
            assertEquals(NotificationType.SYSTEM, hits.get(0).getType(), k);
            assertNull(hits.get(0).getSubtype(), k);
            assertCourseTarget(s, title, courseId);
        }
    }

    // ================= B20 / B21 / B22 / B23 =================

    @Test
    void sessionListShowsPendingCountAndBulkSupportsDryRun() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User member = student("Uye");
        enrol(l, courseId, member);
        long sid = openSession(l, courseId);
        scan(student("Kayitsiz Bir"), code(l, sid));
        scan(student("Kayitsiz Iki"), code(l, sid));
        JsonNode list = call(l, get("/api/academician/courses/" + courseId + "/sessions"), 200);
        assertEquals(2, list.get(0).get("pendingCount").asInt());
        assertEquals(2, call(l, get("/api/academician/sessions/" + sid), 200).get("pendingCount").asInt());

        String dept = "Dryrun Bolumu " + rnd();
        for (int i = 0; i < 3; i++) {
            User u = student("Dry " + i);
            u.setDepartment(dept);
            users.save(u);
        }
        long before = enrollRepo.countByCourseId(courseId);
        JsonNode dry = call(l, postJson("/api/academician/courses/" + courseId + "/enrollments/bulk",
                obj().put("department", dept).put("dryRun", true)), 200);
        assertEquals(3, dry.get("wouldAdd").asInt());
        assertEquals(before, enrollRepo.countByCourseId(courseId)); // hicbir sey degismedi
        assertEquals(3, call(l, postJson("/api/academician/courses/" + courseId + "/enrollments/bulk", obj().put("department", dept)), 200)
                .get("added").asInt());
        // ikinci kuru calistirma: halihazirda kayitlilar sayilmaz
        assertEquals(0, call(l, postJson("/api/academician/courses/" + courseId + "/enrollments/bulk",
                obj().put("department", dept).put("dryRun", true)), 200).get("wouldAdd").asInt());
    }

    @Test
    void exportIncludesOwnScanRequestsAndExcusedFlag() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Kayitli");
        User out = student("Kayitsiz");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        scan(out, code(l, sid));
        excuse(l, sid, s);
        var ex = exporters.stream().filter(e -> e.section().equals("courseAttendance")).findFirst().orElseThrow();
        @SuppressWarnings("unchecked")
        Map<String, Object> mine = (Map<String, Object>) ex.export(out.getId());
        List<?> reqs = (List<?>) mine.get("scanRequests");
        assertEquals(1, reqs.size());
        assertTrue(reqs.get(0).toString().contains("PENDING"));
        assertTrue(reqs.get(0).toString().contains("Veri Yapıları"));
        @SuppressWarnings("unchecked")
        Map<String, Object> sOnly = (Map<String, Object>) ex.export(s.getId());
        assertEquals(0, ((List<?>) sOnly.get("scanRequests")).size()); // baskasinin istegi yok
        assertTrue(((List<?>) sOnly.get("records")).get(0).toString().contains("excused=true"));
    }

    @Test
    void migrationV1905AddsPartialPurgeIndexesAndNoticeIndexMatchesItsOrdering() throws Exception {
        String sql = Files.readString(Path.of("src/main/resources/db/migration/V1905__ak_purge_indexes.sql"));
        for (String col : List.of("ac_attendance (marked_by)", "ac_attendance (revoked_by)", "ac_scan_request (student_id)",
                "ac_scan_request (decided_by)", "ac_notice (created_by)", "ac_notice_file (uploaded_by)", "academician (reviewed_by)")) {
            assertTrue(sql.contains(col), col);
        }
        assertTrue(sql.contains("WHERE marked_by IS NOT NULL"));
        assertTrue(sql.matches("(?s).*ak1900_att_marked_by_idx.*"));
        String notice = Files.readString(Path.of("src/main/resources/db/migration/V1904__ac_notice.sql"));
        assertTrue(notice.contains("ON ac_notice (course_id, id)"), "sayfa sorgusu ORDER BY id DESC ile eslesen indeks");
        assertTrue(notice.contains("deleted_at"));
    }

    // ================= B24 / B25 / B26 =================

    @Test
    void lecturerCanExcludeASessionFromCountsAndTogglingRecomputesWarnings() throws Exception {
        User l = lecturer("Hoca");
        User other = lecturer("Baska");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":1}");
        long sid = sessionOn(l, courseId, 1);
        close(l, sid);
        assertEquals(2, warnedLevel(courseId, s));
        expectError(other, patch("/api/academician/sessions/" + sid).contentType("application/json").content("{\"counted\":false}"),
                404, "AC_SESSION_NOT_FOUND");
        JsonNode off = call(l, patch("/api/academician/sessions/" + sid).contentType("application/json").content("{\"counted\":false}"), 200);
        assertFalse(off.get("counted").asBoolean());
        call(l, patch("/api/academician/sessions/" + sid).contentType("application/json").content("{\"counted\":false}"), 200); // idempotent
        JsonNode m = matrix(l, courseId);
        assertFalse(m.get("sessions").get(0).get("counted").asBoolean());
        JsonNode r = row(m, s);
        assertEquals("ABSENT", r.get("marks").get(String.valueOf(sid)).asText()); // isaret kalir
        assertEquals(0, r.get("sessionCount").asInt());
        assertEquals(0, r.get("absentCount").asInt());
        assertFalse(r.get("overLimit").asBoolean());
        assertEquals(0, myCourse(s).get("sessionCount").asInt());
        assertEquals(0, warnedLevel(courseId, s)); // sessizce dustu
        String csv = new String(raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv")).getContentAsByteArray(),
                java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.contains(" (sayılmıyor)"), csv);
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title"));
        // tekrar sayilirsa yukselir ve bildirir
        assertTrue(call(l, patch("/api/academician/sessions/" + sid).contentType("application/json").content("{\"counted\":true}"), 200)
                .get("counted").asBoolean());
        assertEquals(2, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertTrue(call(l, get("/api/academician/sessions/" + sid), 200).has("counted"));
        assertTrue(call(l, get("/api/academician/sessions/" + sid + "/live"), 200).has("codes"));
    }

    @Test
    void excusedAbsenceIsNeitherPresentNorAbsentAndQrScanTurnsItIntoPresence() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Mazeretli");
        User p = student("Gelen");
        enrol(l, courseId, s, p);
        patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":1}");
        long sid = openSession(l, courseId);
        JsonNode rec = excuse(l, sid, s);
        assertTrue(rec.get("excused").asBoolean());
        assertEquals("MANUAL", rec.get("method").asText());
        scan(p, code(l, sid));
        JsonNode lv = live(l, sid);
        assertEquals(1, lv.get("presentCount").asInt()); // izinli sayilmaz
        boolean sawExcused = false;
        for (JsonNode n : lv.get("newRecords")) {
            if (n.get("studentId").asLong() == s.getId()) {
                sawExcused = n.get("excused").asBoolean();
            }
        }
        assertTrue(sawExcused);
        close(l, sid);
        JsonNode r = row(matrix(l, courseId), s);
        assertEquals("EXCUSED", r.get("marks").get(String.valueOf(sid)).asText());
        assertEquals(0, r.get("absentCount").asInt());
        assertEquals(0, r.get("sessionCount").asInt());
        assertEquals(1, r.get("excusedCount").asInt());
        assertFalse(r.get("overLimit").asBoolean());
        JsonNode mine = myCourse(s);
        assertEquals(1, mine.get("excusedCount").asInt());
        assertEquals(0, mine.get("sessionCount").asInt());
        assertEquals(0, countTitle(s, "notif.academician.absenceExceeded.title"));
        String csv = new String(raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv")).getContentAsByteArray(),
                java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.contains("İzinli"), csv);
        // izinli kaydi silmek duz devamsizliktir
        remove(l, sid, s);
        assertEquals("REVOKED", row(matrix(l, courseId), s).get("marks").get(String.valueOf(sid)).asText());
        assertEquals(1, row(matrix(l, courseId), s).get("absentCount").asInt());
        // izinliyi yeniden isaretle, sonra QR ile gelirse VAR olur (izin kalkar) - oturum yeniden acik
        excuse(l, sid, s);
        call(l, postJson("/api/academician/sessions/" + sid + "/reopen", null), 200);
        assertEquals("MARKED", scan(s, code(l, sid)).get("status").asText());
        AcAttendance a = attendRepo.findBySessionIdAndStudentId(sid, s.getId()).orElseThrow();
        assertFalse(a.isExcused());
        assertEquals(AcAttendance.Method.QR, a.getMethod());
        // izinli satirda body'siz PUT "var" sayar
        User q = student("Sonradan");
        enrol(l, courseId, q);
        excuse(l, sid, q);
        assertEquals("MANUAL", call(l, put("/api/academician/sessions/" + sid + "/records/" + q.getId()), 200).get("method").asText());
        assertFalse(attendRepo.findBySessionIdAndStudentId(sid, q.getId()).orElseThrow().isExcused());
    }

    @Test
    void plannedSessionsTurnPercentIntoAnAbsenceCountWithTheSameSemantics() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        JsonNode c = patchCourse(l, courseId,
                "{\"absenceLimitType\":\"PERCENT\",\"absenceLimitValue\":20,\"plannedSessions\":10}");
        assertEquals(10, c.get("plannedSessions").asInt());
        assertEquals(2, c.get("limit").get("allowedAbsences").asInt());
        assertEquals(2, matrix(l, courseId).get("limit").get("allowedAbsences").asInt());
        long s1 = sessionOn(l, courseId, 2);
        close(l, s1);
        // 1 devamsizlik, izinli 2: bir daha -> risk (ilk ders %100 gibi gorunmez)
        JsonNode r = row(matrix(l, courseId), s);
        assertTrue(r.get("atRisk").asBoolean());
        assertEquals(1, countTitle(s, "notif.academician.absenceWarning.title"));
        long s2 = sessionOn(l, courseId, 1);
        close(l, s2);
        assertTrue(row(matrix(l, courseId), s).get("overLimit").asBoolean()); // 2 = sinira ulasti
        String csv = new String(raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv")).getContentAsByteArray(),
                java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.contains("Sınıra ulaştı"), csv);
        // planlanan temizlenince (0) eski kural: sayilan 2 < 4 -> durum yok, allowedAbsences null
        JsonNode cleared = patchCourse(l, courseId, "{\"plannedSessions\":0}");
        assertTrue(cleared.get("plannedSessions").isNull());
        assertTrue(cleared.get("limit").get("allowedAbsences").isNull());
        assertFalse(row(matrix(l, courseId), s).get("overLimit").asBoolean());
        // COUNT'ta allowedAbsences = deger
        assertEquals(3, patchCourse(l, courseId, "{\"absenceLimitType\":\"COUNT\",\"absenceLimitValue\":3}")
                .get("limit").get("allowedAbsences").asInt());
        // gecersiz planlanan
        expectError(l, patch("/api/academician/courses/" + courseId).contentType("application/json").content("{\"plannedSessions\":401}"),
                400, "VALIDATION_ERROR");
        // ders olusturmada da verilebilir
        ObjectNode body = obj().put("name", "Planli").put("term", "t").put("faculty", FACULTY).put("department", DEPT).put("plannedSessions", 14);
        assertEquals(14, call(l, postJson("/api/academician/courses", body), 201).get("plannedSessions").asInt());
    }
}
