package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import edu.bingol.backend.user.User;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/** Hocanin son sozu (kayit silme/geri alma), devamsizlik matrisi + CSV, sinirlar ve otomatik devamsizlik uyarisi, Derslerim. */
class AcademicianAttendanceMvcTest extends AcademicianMvcBase {

    private long sessionOn(User l, long courseId, int daysAgo) {
        JsonNode s = call(l, postJson("/api/academician/courses/" + courseId + "/sessions",
                obj().put("lessonDate", LocalDate.now().minusDays(daysAgo).toString())), 201);
        return s.get("id").asLong();
    }

    private void close(User l, long sid) {
        call(l, postJson("/api/academician/sessions/" + sid + "/close", null), 200);
    }

    private void markPresent(User l, long sid, User s) {
        call(l, put("/api/academician/sessions/" + sid + "/records/" + s.getId()), 200);
    }

    private void remove(User l, long sid, User s) {
        call(l, delete("/api/academician/sessions/" + sid + "/records/" + s.getId()), 204);
    }

    private JsonNode matrix(User l, long courseId) {
        return call(l, get("/api/academician/courses/" + courseId + "/attendance"), 200);
    }

    private static JsonNode row(JsonNode matrix, User s) {
        for (JsonNode r : matrix.get("students")) {
            if (r.get("studentId").asLong() == s.getId()) {
                return r;
            }
        }
        throw new AssertionError("ogrenci satiri yok: " + s.getId());
    }

    private void limit(User l, long courseId, String type, int value) {
        call(l, MockMvcRequestBuilders.patch("/api/academician/courses/" + courseId).contentType("application/json")
                .content(obj().put("absenceLimitType", type).put("absenceLimitValue", value).toString()), 200);
    }

    @Test
    void lecturerRemovalSticksUntilRestoredAndWorksOnClosedSessions() throws Exception {
        User l = lecturer("Hoca");
        User other = lecturer("Baska");
        long courseId = course(l);
        User s = student("Silinecek");
        User notEnrolled = student("Kayitsiz");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        assertEquals("MARKED", scan(s, code).get("status").asText());

        // baska hoca dokunamaz
        expectError(other, delete("/api/academician/sessions/" + sid + "/records/" + s.getId()), 404, "AC_SESSION_NOT_FOUND");
        assertEquals(1, attendRepo.countActive(sid));

        // kayitli olmayan icin elle isaretleme 404
        expectError(l, put("/api/academician/sessions/" + sid + "/records/" + notEnrolled.getId()), 404, "AC_STUDENT_NOT_ENROLLED");
        // kaydi olmayan icin silme no-op
        call(l, delete("/api/academician/sessions/" + sid + "/records/" + notEnrolled.getId()), 204);

        long pollBefore = live(l, sid).get("newRecords").size();
        assertEquals(1, pollBefore);
        assertFalse(live(l, sid).get("newRecords").get(0).get("revoked").asBoolean());

        // QR ile gelen kayit da silinebilir; sonraki yoklamada GORUNUR (revoked:true), sayac duser
        remove(l, sid, s);
        JsonNode lv = live(l, sid);
        assertEquals(1, lv.get("newRecords").size());
        assertTrue(lv.get("newRecords").get(0).get("revoked").asBoolean());
        assertEquals(0, lv.get("presentCount").asInt());
        assertEquals("REVOKED", row(matrix(l, courseId), s).get("marks").get(String.valueOf(sid)).asText());
        assertEquals(1, row(matrix(l, courseId), s).get("absentCount").asInt());
        remove(l, sid, s); // idempotent

        // ayni oturumda tekrar tarama: 403, satir degismez, yine devamsiz
        expectError(s, scanReq(code(l, sid)), 403, "ATTENDANCE_REVOKED");
        assertEquals(0, attendRepo.countActive(sid));

        // kapali oturumda da silme/ekleme calisir; elle geri alma MANUAL yapar
        close(l, sid);
        JsonNode restored = call(l, put("/api/academician/sessions/" + sid + "/records/" + s.getId()), 200);
        assertEquals("MANUAL", restored.get("method").asText());
        assertFalse(restored.get("revoked").asBoolean());
        AcAttendance a = attendRepo.findBySessionIdAndStudentId(sid, s.getId()).orElseThrow();
        assertEquals(AcAttendance.Method.MANUAL, a.getMethod());
        assertEquals(l.getId(), a.getMarkedBy());
        assertEquals(null, a.getRevokedAt());
        assertEquals("PRESENT_MANUAL", row(matrix(l, courseId), s).get("marks").get(String.valueOf(sid)).asText());
        assertEquals(1, live(l, sid).get("presentCount").asInt());

        // gecerli QR kaydinda PUT idempotent: yontem degismez
        User s2 = student("Qr Kalir");
        enrol(l, courseId, s2);
        call(l, postJson("/api/academician/sessions/" + sid + "/reopen", null), 200);
        assertEquals("MARKED", scan(s2, code(l, sid)).get("status").asText());
        assertEquals("QR", call(l, put("/api/academician/sessions/" + sid + "/records/" + s2.getId()), 200).get("method").asText());
        close(l, sid);
        remove(l, sid, s2); // kapali oturumda silme
        assertEquals("REVOKED", row(matrix(l, courseId), s2).get("marks").get(String.valueOf(sid)).asText());
    }

    @Test
    void matrixCsvAndCountsReflectEachState() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User qr = student("Qr Ogrenci");
        User manual = student("Elle Ogrenci");
        User revoked = student("Silinmis Ogrenci");
        User absent = student("=1+1");
        enrol(l, courseId, qr, manual, revoked, absent);

        long s1 = sessionOn(l, courseId, 2);
        assertEquals("MARKED", scan(qr, code(l, s1)).get("status").asText());
        assertEquals("MARKED", scan(revoked, code(l, s1)).get("status").asText());
        markPresent(l, s1, manual);
        remove(l, s1, revoked);
        close(l, s1);
        long s2 = sessionOn(l, courseId, 1);
        close(l, s2);

        JsonNode m = matrix(l, courseId);
        assertEquals(2, m.get("sessions").size());
        assertEquals(String.valueOf(s1), m.get("sessions").get(0).get("id").asText());
        String k1 = String.valueOf(s1);
        String k2 = String.valueOf(s2);
        assertEquals("PRESENT_QR", row(m, qr).get("marks").get(k1).asText());
        assertEquals("PRESENT_MANUAL", row(m, manual).get("marks").get(k1).asText());
        assertEquals("REVOKED", row(m, revoked).get("marks").get(k1).asText());
        assertEquals("ABSENT", row(m, absent).get("marks").get(k1).asText());
        assertEquals("ABSENT", row(m, qr).get("marks").get(k2).asText());
        assertEquals(1, row(m, qr).get("absentCount").asInt());
        assertEquals(1, row(m, manual).get("absentCount").asInt());
        assertEquals(2, row(m, revoked).get("absentCount").asInt());
        assertEquals(2, row(m, absent).get("absentCount").asInt());
        assertTrue(row(m, qr).get("studentNo").asText().matches("\\d+"));
        assertTrue(m.get("limit").get("type").isNull());

        // CSV: BOM, CRLF, ogrenci basina tek satir, dort durum, formul kacisi
        MockHttpServletResponse res = raw(l, get("/api/academician/courses/" + courseId + "/attendance.csv"));
        assertEquals(200, res.getStatus());
        assertTrue(res.getContentType().startsWith("text/csv"));
        assertTrue(res.getHeader("Content-Disposition").startsWith("attachment"));
        byte[] bytes = res.getContentAsByteArray();
        assertEquals((byte) 0xEF, bytes[0]);
        assertEquals((byte) 0xBB, bytes[1]);
        assertEquals((byte) 0xBF, bytes[2]);
        String csv = new String(bytes, 3, bytes.length - 3, StandardCharsets.UTF_8);
        String[] lines = csv.split("\r\n");
        assertEquals(1 + 4, lines.length, csv);
        assertTrue(lines[0].startsWith("Öğrenci No,Ad Soyad,"), lines[0]);
        assertTrue(csv.contains("Var (QR)") && csv.contains("Var (elle)") && csv.contains("Silindi") && csv.contains("Yok"), csv);
        assertTrue(csv.contains("\"'=1+1\""), "formul onekli ad kacirilmali: " + csv);
        assertFalse(csv.contains(",=1+1,"));

        // Derslerim: sayilar matrisle ayni
        JsonNode mine = call(qr, get("/api/my-courses"), 200);
        assertEquals(1, mine.size());
        JsonNode c = mine.get(0);
        assertEquals(courseId, c.get("courseId").asLong());
        assertEquals(1, c.get("presentCount").asInt());
        assertEquals(1, c.get("absentCount").asInt());
        assertEquals(2, c.get("sessionCount").asInt());
        assertEquals("Veri Yapıları", c.get("courseName").asText());
        assertTrue(c.get("limit").isNull());
        assertFalse(c.get("atRisk").asBoolean());
        JsonNode rv = call(revoked, get("/api/my-courses"), 200).get(0);
        assertEquals(0, rv.get("presentCount").asInt()); // silinmis kayit devamsiz sayilir
        assertEquals(2, rv.get("absentCount").asInt());
        for (User u : List.of(qr, manual, revoked, absent)) {
            JsonNode mc = call(u, get("/api/my-courses"), 200).get(0);
            JsonNode mr = row(matrix(l, courseId), u);
            assertEquals(mr.get("absentCount").asInt(), mc.get("absentCount").asInt());
        }
        assertEquals(0, call(student("Hicbir Derse Kayitli Degil"), get("/api/my-courses"), 200).size());
    }

    @Test
    void absenceLimitCountAndPercentSetAtRiskAndOverLimit() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Devamsiz");
        enrol(l, courseId, s);
        long[] sids = new long[4];
        for (int i = 0; i < 4; i++) {
            sids[i] = sessionOn(l, courseId, 4 - i);
            if (i < 3) {
                markPresent(l, sids[i], s);
            }
            close(l, sids[i]);
        }
        limit(l, courseId, "COUNT", 2);
        JsonNode r = row(matrix(l, courseId), s);
        assertEquals(1, r.get("absentCount").asInt());
        assertTrue(r.get("atRisk").asBoolean());
        assertFalse(r.get("overLimit").asBoolean());
        assertEquals("COUNT", matrix(l, courseId).get("limit").get("type").asText());
        assertEquals(2, matrix(l, courseId).get("limit").get("value").asInt());
        remove(l, sids[0], s);
        r = row(matrix(l, courseId), s);
        assertEquals(2, r.get("absentCount").asInt());
        assertFalse(r.get("atRisk").asBoolean());
        assertTrue(r.get("overLimit").asBoolean());
        JsonNode mine = call(s, get("/api/my-courses"), 200).get(0);
        assertTrue(mine.get("overLimit").asBoolean());
        assertEquals("COUNT", mine.get("limit").get("type").asText());

        // yuzde: 4 oturumun 2'si = %50 -> ulasildi; 1/4 = %25 -> bir daha kacarsa 2/5 = %40 < %50: risk yok
        limit(l, courseId, "PERCENT", 50);
        assertTrue(row(matrix(l, courseId), s).get("overLimit").asBoolean());
        markPresent(l, sids[0], s);
        r = row(matrix(l, courseId), s);
        assertEquals(1, r.get("absentCount").asInt());
        assertFalse(r.get("overLimit").asBoolean());
        assertFalse(r.get("atRisk").asBoolean());
        // siniri kaldir
        call(l, MockMvcRequestBuilders.patch("/api/academician/courses/" + courseId).contentType("application/json")
                .content("{\"absenceLimitType\":\"NONE\"}"), 200);
        assertFalse(row(matrix(l, courseId), s).get("atRisk").asBoolean());
        // gecersiz sinir
        expectError(l, MockMvcRequestBuilders.patch("/api/academician/courses/" + courseId).contentType("application/json")
                .content("{\"absenceLimitType\":\"PERCENT\",\"absenceLimitValue\":101}"), 400, "AC_FIELD_INVALID");
    }

    @Test
    void absenceWarningsFireOncePerLevelAndLowerSilently() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Uyarilan");
        User ok = student("Duzenli");
        enrol(l, courseId, s, ok);
        long s1 = sessionOn(l, courseId, 3);
        markPresent(l, s1, ok);
        // sinir yokken kapatma bildirim uretmez
        close(l, s1);
        assertEquals(0, countTitle(s, "notif.academician.absenceWarning.title"));
        // sinir konunca (COUNT 2) yeniden hesap: 1 devamsizlik = risk (duzey 1)
        limit(l, courseId, "COUNT", 2);
        assertEquals(1, countTitle(s, "notif.academician.absenceWarning.title"));
        assertEquals(0, countTitle(ok, "notif.academician.absenceWarning.title"));
        // ayni duzey iki kez bildirilmez: kapali oturumu yeniden kapatmak/okumak yeni bildirim vermez
        close(l, s1);
        call(l, get("/api/academician/courses/" + courseId + "/sessions"), 200);
        assertEquals(1, countTitle(s, "notif.academician.absenceWarning.title"));

        long s2 = sessionOn(l, courseId, 2);
        markPresent(l, s2, ok);
        close(l, s2);
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title")); // 2 devamsizlik = sinira ulasildi
        assertEquals(1, countTitle(s, "notif.academician.absenceWarning.title"));
        long warned = enrollRepo.ofCourse(courseId, org.springframework.data.domain.PageRequest.of(0, 10)).stream()
                .filter(e -> e.getStudentId().equals(s.getId())).findFirst().orElseThrow().getWarnedLevel();
        assertEquals(2, warned);

        // hoca duzeltir: duzey sessizce duser (bildirim yok)
        markPresent(l, s2, s);
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertEquals(1, countTitle(s, "notif.academician.absenceWarning.title"));
        assertEquals(1, warnedLevel(courseId, s));
        // yeniden asinca TEKRAR bildirilir
        remove(l, s2, s);
        assertEquals(2, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertEquals(2, warnedLevel(courseId, s));
        // derse zaten bildirilmis ogrenci tekrar bildirilmez
        remove(l, s2, s);
        assertEquals(2, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertEquals(0, countTitle(ok, "notif.academician.absenceExceeded.title"));
    }

    private long warnedLevel(long courseId, User s) {
        return enrollRepo.ofCourse(courseId, org.springframework.data.domain.PageRequest.of(0, 10)).stream()
                .filter(e -> e.getStudentId().equals(s.getId())).findFirst().orElseThrow().getWarnedLevel();
    }

    @Test
    void expiredSessionIsFinalisedOnceWhenFirstObserved() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Gelmeyen");
        enrol(l, courseId, s);
        limit(l, courseId, "COUNT", 1);
        long sid = sessionOn(l, courseId, 1);
        // sure doldu ama kimse kapatmadi
        AcSession ses = sessionRepo.findById(sid).orElseThrow();
        ses.setExpiresAt(Instant.now().minusSeconds(60));
        sessionRepo.save(ses);
        assertEquals(0, countTitle(s, "notif.academician.absenceExceeded.title"));
        // ilk gozlem kesinlestirir; ikinci/ucuncu gozlem tekrar bildirmez
        assertEquals("CLOSED", call(l, get("/api/academician/sessions/" + sid), 200).get("status").asText());
        call(l, get("/api/academician/sessions/" + sid + "/live"), 200);
        call(l, get("/api/academician/courses/" + courseId + "/sessions"), 200);
        assertEquals(1, countTitle(s, "notif.academician.absenceExceeded.title"));
        assertEquals(AcSession.Status.CLOSED, sessionRepo.findById(sid).orElseThrow().getStatus());
        // es zamanli iki kesinlestirme tek bildirim: kosullu UPDATE yalniz birine 1 doner
        long sid2 = sessionOn(l, courseId, 2);
        AcSession s2 = sessionRepo.findById(sid2).orElseThrow();
        assertEquals(1, sessionRepo.closeIfOpen(sid2, Instant.now()));
        assertEquals(0, sessionRepo.closeIfOpen(sid2, Instant.now()));
        assertEquals(AcSession.Status.CLOSED, sessionRepo.findById(s2.getId()).orElseThrow().getStatus());
    }
}
